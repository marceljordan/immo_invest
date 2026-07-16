# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "66841f6d-142d-4f8a-98ff-9b81fed41000",
# META       "default_lakehouse_name": "LH_Immo_Dev",
# META       "default_lakehouse_workspace_id": "ec7aa1ee-16a6-43ef-a54d-cdcc1cb90693",
# META       "known_lakehouses": [
# META         {
# META           "id": "66841f6d-142d-4f8a-98ff-9b81fed41000"
# META         }
# META       ]
# META     },
# META     "environment": {
# META       "environmentId": "83eb490a-658e-a9c3-4f2a-0c23f7ee1105",
# META       "workspaceId": "00000000-0000-0000-0000-000000000000"
# META     },
# META     "warehouse": {
# META       "known_warehouses": []
# META     }
# META   }
# META }

# CELL ********************

# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {"name": "synapse_pyspark"},
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse_name": "LH_Immo_Dev"
# META     }
# META   }
# META }

# CELL ********************

# ============================================================
# NB_01_Simulateur — extract CDC quotidien J-1
# ============================================================
# Modèle d'ingestion : Change Data Capture par version complète.
#
#   Le CRM source n'émet pas des deltas de champs. Il émet la ligne
#   entière d'un enregistrement dès qu'un de ses champs change, avec
#   updated_at = horodatage du changement.
#
#   Bronze accumule les versions (APPEND, jamais d'UPDATE).
#   Silver garde la dernière version par clé (dédoublonnage).
#   Gold peut alors construire des dimensions SCD Type 2.
#
# Conséquences :
#   - src_lots_immobiliers aura N lignes pour un même lot_id.
#     C'est voulu : DISPONIBLE, puis RESERVE, puis VENDU.
#   - updated_at est le watermark. created_at ne bouge jamais.
#   - Toutes les colonnes sont écrites en varchar, comme la source.
#     Le typage est la responsabilité de Silver.
#
# Modes :
#   quotidien : DATE_DEBUT = DATE_FIN = None   -> J-1
#   backfill  : DATE_DEBUT = '2025-01-02', DATE_FIN = '2026-07-08'
# ============================================================

import pandas as pd
import numpy as np
from faker import Faker
from datetime import datetime, date, timedelta
import random
import uuid
import warnings

warnings.filterwarnings("ignore")

from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, DateType, LongType, TimestampType

fake = Faker("fr_FR")

# CELL ********************

# ============================================================
# PARAMÈTRES
# ============================================================

DATE_DEBUT = None
DATE_FIN = None
MODE = "append"            # 'append' | 'dry_run'
FORCER = False
EXCLURE_JOURS_FERIES = True

# --- Volume exogène : seuls les prospects arrivent "de nulle part".
#     Tout le reste est déclenché par ce qui existe déjà en base.
PROSPECTS_PAR_JOUR = (15, 25)

# --- Cycle commercial (jours). (min, mode, max) -> loi triangulaire.
DELAI_RETRACTATION_SRU = 10          # art. L271-1 CCH : 10 jours incompressibles

FIN_DEMANDE = (0, 3, 7)              # réservation -> dépôt du dossier bancaire
FIN_ACCORD = (14, 21, 35)            # dépôt -> accord de principe
FIN_OFFRE = (21, 30, 42)             # accord -> édition de l'offre de prêt
FIN_ACCEPTATION = (11, 15, 30)       # offre -> acceptation (10 j de réflexion légaux)
TAUX_REFUS_PRET = 0.12

VENTE_ACTE = (45, 90, 150)           # signature du contrat -> acte authentique
VENTE_LIVRAISON = (365, 640, 900)    # VEFA

ADV_PIECES = (5, 12, 30)
ADV_VALIDATION = (3, 8, 25)
ADV_NOTAIRE = (2, 5, 15)
ADV_SIGNATURE = (15, 30, 60)
ADV_TAUX_BLOCAGE = 0.20

COMM_VALIDATION = (1, 7, 15)
COMM_PAIEMENT = (15, 25, 45)
COMM_TAUX_BLOCAGE = 0.05

GL_APRES_LIVRAISON = (0, 20, 60)     # livraison -> entrée en gestion locative
RECLA_PROBA_JOUR = 0.40
RECLA_RESOLUTION = (2, 12, 60)

# --- Funnel CRM : probabilités quotidiennes de transition
P_CONTACTE = 0.35
P_QUALIFIE = 0.12
P_PERDU = 0.05
P_CHAUD = 0.08
P_CONVERSION = 0.06
KYC_DELAI = (3, 8, 20)
TAUX_KYC_REFUSE = 0.03

AFFINITE_REGIONALE = 0.65
RENOUVELLEMENT_TRIMESTRIEL = True
NB_NOUVEAUX_PROGRAMMES = (5, 8)

# CELL ********************

# ============================================================
# CALENDRIER
# ============================================================


def paques(annee):
    """Meeus/Jones/Butcher."""
    a = annee % 19
    b, c = divmod(annee, 100)
    d, e_ = divmod(b, 4)
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = divmod(c, 4)
    l = (32 + 2 * e_ + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    mois, jour = divmod(h + l - 7 * m + 114, 31)
    return date(annee, mois, jour + 1)


_FERIES_CACHE = {}


def jours_feries(annee):
    if annee not in _FERIES_CACHE:
        p = paques(annee)
        _FERIES_CACHE[annee] = {
            date(annee, 1, 1), p + timedelta(days=1), date(annee, 5, 1),
            date(annee, 5, 8), p + timedelta(days=39), p + timedelta(days=50),
            date(annee, 7, 14), date(annee, 8, 15), date(annee, 11, 1),
            date(annee, 11, 11), date(annee, 12, 25),
        }
    return _FERIES_CACHE[annee]


def est_ouvre(d):
    if d.weekday() >= 5:
        return False
    return not (EXCLURE_JOURS_FERIES and d in jours_feries(d.year))


def jour_ouvre_suivant(d):
    while not est_ouvre(d):
        d += timedelta(days=1)
    return d


def tri(bornes):
    """Délai tiré dans une loi triangulaire (min, mode, max), en jours."""
    lo, mode, hi = bornes
    return int(round(random.triangular(lo, hi, mode)))


def apres(d, bornes):
    """Date ouvrée obtenue en ajoutant un délai triangulaire à d."""
    return jour_ouvre_suivant(d + timedelta(days=tri(bornes)))


def saisonnalite(d):
    f = {1: 0.85, 2: 0.95, 3: 1.05, 4: 1.05, 5: 1.10, 6: 1.05,
         7: 0.90, 8: 0.55, 9: 1.10, 10: 1.15, 11: 1.15, 12: 1.20}
    return f.get(d.month, 1.0)

# CELL ********************

# ============================================================
# SÉRIALISATION — Bronze est intégralement varchar
# ============================================================


def s(v):
    """Sérialise une valeur Python vers le texte que la source émettrait."""
    if v is None or (isinstance(v, float) and v != v):
        return None
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, datetime):
        return v.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(v, date):
        return v.isoformat()
    if isinstance(v, float):
        return f"{v:.2f}"
    return str(v)


def gen_id(prefix):
    return f"{prefix}-{uuid.uuid4().hex[:8].upper()}"


_HORLOGE = {}


def ts(d):
    """Horodatage strictement croissant dans la journée ouvrée.

    Indispensable : Silver dédoublonne par MAX(updated_at). Si deux versions
    d'une même clé émises le même jour recevaient des heures aléatoires,
    la dernière version pourrait porter l'horodatage le plus ancien et
    serait silencieusement écartée.
    """
    cur = _HORLOGE.get(d)
    if cur is None:
        cur = datetime.combine(d, datetime.min.time()) + timedelta(hours=8)
    cur += timedelta(seconds=random.randint(1, 6))
    _HORLOGE[d] = cur
    return cur


def read_bronze(table):
    full_name = f"dbo.{table}"
    print("Lecture :", full_name)
    return spark.table(full_name).toPandas()

def derniere_version(pdf, cle, horodatage="updated_at"):
    """Dédoublonne un extract CDC : garde la version la plus récente par clé."""
    if len(pdf) == 0 or cle not in pdf.columns:
        return pdf
    if horodatage not in pdf.columns:
        return pdf.drop_duplicates(subset=[cle], keep="last")
    pdf = pdf.copy()
    pdf["_ts"] = pd.to_datetime(pdf[horodatage], errors="coerce")
    pdf = pdf.sort_values("_ts").drop_duplicates(subset=[cle], keep="last")
    return pdf.drop(columns=["_ts"])

# CELL ********************

# ============================================================
# BUS D'ÉMISSION
# ------------------------------------------------------------
# Une seule règle : emettre(table, record) ajoute une VERSION.
# Jamais d'UPDATE. Le record contient toujours toutes les colonnes.
# ============================================================


class Bus:
    def __init__(self):
        self.buffer = {}
        self.journal = []

    def emettre(self, table, record, d):
        self.buffer.setdefault(table, []).append(dict(record))
        self.journal.append((d, table))

    def resume(self):
        return {t: len(v) for t, v in self.buffer.items()}


BUS = Bus()

# CELL ********************

# ============================================================
# RÉSOLUTION DES DATES
# ============================================================


def resoudre_dates():
    if DATE_DEBUT is None and DATE_FIN is None:
        cibles = [date.today() - timedelta(days=1)]
    else:
        d0 = date.fromisoformat(DATE_DEBUT)
        d1 = date.fromisoformat(DATE_FIN) if DATE_FIN else d0
        if d1 < d0:
            raise ValueError("DATE_FIN < DATE_DEBUT")
        cibles = [d0 + timedelta(days=i) for i in range((d1 - d0).days + 1)]
    return [d for d in cibles if est_ouvre(d)]


def dates_deja_produites():
    if FORCER:
        return set()
    try:
        rows = spark.sql(
            "SELECT DISTINCT date_cible FROM dbo.tech_simulation_run_log"
        ).collect()
        return {r["date_cible"] for r in rows}
    except Exception:
        return set()


DATES_CIBLES = resoudre_dates()
DEJA = dates_deja_produites()
A_TRAITER = [d for d in DATES_CIBLES if d not in DEJA]

print(f"🎯 candidates : {len(DATES_CIBLES)}   déjà produites : {len(DATES_CIBLES) - len(A_TRAITER)}   à traiter : {len(A_TRAITER)}")

# CELL ********************

# ============================================================
# CONTRAT DE SCHÉMA
# ------------------------------------------------------------
# Copié depuis INFORMATION_SCHEMA.COLUMNS de LH_Immo_Dev.
# emettre() refuse tout enregistrement qui s'en écarte : c'est ce
# qui empêche d'inventer une colonne ou d'en oublier une.
# ============================================================

COLS = {
"src_crm_prospects": [
    "prospect_id","civilite","nom","prenom","email","telephone","date_naissance","ville",
    "code_postal","pays","situation_familiale","profession","revenu_annuel_estime",
    "patrimoine_estime","capacite_investissement","objectif_investissement",
    "horizon_investissement","appetence_risque","source_acquisition","campagne_marketing",
    "canal_acquisition","statut_prospect","score_qualification","date_creation","created_by",
    "last_update_date","last_updated_by","is_deleted"],

"src_crm_investisseurs": [
    "investisseur_id","prospect_id","civilite","nom","prenom","email","telephone","adresse",
    "ville","code_postal","pays","profession","situation_familiale","revenu_annuel",
    "patrimoine_financier","patrimoine_immobilier","profil_investisseur","objectif_principal",
    "horizon_placement","niveau_experience","statut_kyc","statut_lcbft","date_entree_relation",
    "partenaire_id","conseiller_id","agence_id","statut_client","date_creation","created_by",
    "last_update_date","last_updated_by","is_deleted"],

"src_reservations_immobilieres": [
    "reservation_id","lot_id","programme_id","investisseur_id","partenaire_id","conseiller_id",
    "agence_id","date_reservation","montant_reservation","prix_reserve","remise_appliquee",
    "statut_reservation","motif_annulation","date_annulation","date_expiration_reservation",
    "canal_reservation","mode_financement_prevu","apport_prevu","montant_credit_prevu",
    "commentaire_commercial","created_at","updated_at","is_deleted"],

"src_ventes_immobilieres": [
    "vente_id","reservation_id","lot_id","programme_id","investisseur_id","partenaire_id",
    "conseiller_id","agence_id","date_signature_contrat","date_signature_acte",
    "date_livraison_prevue","date_livraison_reelle","prix_vente_ht","prix_vente_ttc","tva",
    "frais_notaire","montant_total_operation","mode_financement","montant_apport",
    "montant_credit","banque_financement","statut_vente","motif_echec","created_at",
    "updated_at","is_deleted"],

"src_financements": [
    "financement_id","vente_id","investisseur_id","banque","courtier","montant_demande",
    "montant_accorde","taux_credit","duree_credit_mois","mensualite_estimee",
    "statut_financement","date_demande","date_accord_principe","date_offre_pret",
    "date_acceptation_offre","motif_refus","apport_personnel","assurance_emprunteur",
    "created_at","updated_at","is_deleted"],

"src_commissions": [
    "commission_id","type_operation","operation_id","vente_id","souscription_id",
    "operation_crowdfunding_id","investisseur_id","partenaire_id","conseiller_id","agence_id",
    "produit_id","programme_id","montant_operation","taux_commission","montant_commission_brut",
    "montant_commission_net","part_commission_partenaire","part_commission_interne",
    "statut_commission","date_calcul","date_validation","date_paiement","mode_paiement",
    "motif_blocage","created_at","updated_at","is_deleted"],

"src_dossiers_adv": [
    "dossier_adv_id","vente_id","reservation_id","investisseur_id","lot_id","programme_id",
    "partenaire_id","conseiller_id","statut_dossier","date_ouverture_dossier",
    "date_reception_pieces","date_validation_dossier","date_envoi_notaire","date_signature_acte",
    "delai_traitement_jours","pieces_manquantes","nombre_relances","blocage_adv","motif_blocage",
    "responsable_adv_id","commentaire_adv","created_at","updated_at","is_deleted"],

"src_souscriptions_pierre_papier": [
    "souscription_id","investisseur_id","partenaire_id","conseiller_id","agence_id","produit_id",
    "societe_gestion_id","type_support","nom_support","date_souscription","montant_souscrit",
    "nombre_parts","prix_part","frais_souscription","duree_recommandee","rendement_previsionnel",
    "statut_souscription","date_validation","date_rejet","motif_rejet","mode_paiement",
    "created_at","updated_at","is_deleted"],

"src_gestion_locative": [
    "gestion_id","vente_id","lot_id","investisseur_id","programme_id","gestionnaire_id",
    "date_debut_gestion","date_fin_gestion","statut_gestion","loyer_mensuel_prevu",
    "loyer_mensuel_reel","taux_occupation","vacance_locative_jours","charges_mensuelles",
    "incident_locatif","montant_impayes","rendement_reel_annuel","created_at","updated_at",
    "is_active"],

"src_reclamations_incidents": [
    "reclamation_id","investisseur_id","partenaire_id","operation_id","type_operation",
    "type_reclamation","categorie_reclamation","niveau_urgence","statut_reclamation",
    "date_ouverture","date_resolution","delai_resolution_jours","responsable_traitement_id",
    "motif_reclamation","resolution_apportee","impact_financier_estime","created_at",
    "updated_at","is_deleted"],

"src_revente_biens": [
    "revente_id","vente_id","lot_id","investisseur_id","programme_id","date_demande_revente",
    "date_mise_en_marche","date_revente","prix_achat_initial","prix_revente_estime",
    "prix_revente_final","plus_value_brute","plus_value_nette","statut_revente","motif_revente",
    "mandat_revente","conseiller_revente_id","nombre_visites","created_at","updated_at",
    "is_deleted"],

"src_expertise_comptable_lmnp": [
    "dossier_comptable_id","investisseur_id","vente_id","lot_id","programme_id","annee_fiscale",
    "regime_fiscal","statut_dossier_comptable","date_ouverture","date_reception_documents",
    "date_declaration","recettes_locatives","charges_deductibles","amortissements",
    "resultat_fiscal","impot_estime","comptable_id","nombre_relances","pieces_manquantes",
    "created_at","updated_at","is_deleted"],

"src_evenements_clients": [
    "evenement_id","investisseur_id","prospect_id","partenaire_id","conseiller_id",
    "type_evenement","canal_evenement","objet_evenement","date_evenement","statut_evenement",
    "resultat_evenement","prochaine_action","date_prochaine_action","priorite","commentaire",
    "created_at","created_by","updated_at","is_deleted"],

"src_operations_crowdfunding": [
    "operation_crowdfunding_id","investisseur_id","partenaire_id","conseiller_id","agence_id",
    "projet_id","nom_projet","promoteur_id","ville","region","date_investissement",
    "montant_investi","taux_rendement_annuel_prevu","duree_mois","statut_operation",
    "date_remboursement_prevue","date_remboursement_reelle","montant_rembourse","interets_bruts",
    "fiscalite_appliquee","incident_paiement","created_at","updated_at","is_deleted"],

# --- Référentiels mutables (versions émises aussi) ---
"src_lots_immobiliers": [
    "lot_id","programme_id","numero_lot","type_lot","typologie","surface_m2","etage",
    "orientation","parking_inclus","prix_catalogue","prix_remise","prix_final",
    "loyer_estime_mensuel","rentabilite_brute_estimee","statut_lot","date_disponibilite",
    "date_reservation","date_vente","investisseur_id","partenaire_id","created_at","updated_at",
    "is_active"],

"src_programmes_immobiliers": [
    "programme_id","nom_programme","type_programme","promoteur_id","ville","code_postal",
    "region","adresse","latitude","longitude","type_actif","segment_marche","statut_programme",
    "date_lancement_commercial","date_livraison_prevue","date_livraison_reelle",
    "nombre_lots_total","nombre_lots_disponibles","prix_moyen_m2","rentabilite_cible",
    "zone_fiscale","dispositif_fiscal","label_energetique","note_programme","created_at",
    "updated_at","is_active"],
}


def emettre(table, rec, d):
    """Émet une version complète. Valide le contrat de schéma."""
    attendu = set(COLS[table])
    recu = set(rec)
    if recu != attendu:
        manquant, extra = attendu - recu, recu - attendu
        raise KeyError(f"{table} : manquant={sorted(manquant)} extra={sorted(extra)}")
    BUS.emettre(table, {c: rec[c] for c in COLS[table]}, d)

# CELL ********************

# ============================================================
# ÉTAT + AGENDA
# ------------------------------------------------------------
# L'agenda est la clé du réalisme : à la création d'un dossier on
# planifie toutes ses étapes futures. Chaque jour, on exécute celles
# qui tombent. Un dossier ouvert le 3 mars signe chez le notaire le
# 18 juin sans qu'aucune boucle n'ait besoin de le scanner.
# ============================================================

from collections import defaultdict


def _num(v, defaut=0.0):
    try:
        return float(v)
    except (TypeError, ValueError):
        return defaut


def _int(v, defaut=0):
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return defaut


def _dt(v):
    try:
        return pd.to_datetime(v).date()
    except Exception:
        return None


BANQUES = ["BNP Paribas", "Crédit Agricole", "Société Générale", "LCL", "CIC",
           "Banque Populaire", "Caisse d'Épargne", "Crédit Mutuel", "HSBC France"]
COURTIERS = ["Cafpi", "Meilleurtaux", "Empruntis", "Vousfinancer", None]
MOTIFS_REFUS = ["Taux d'endettement supérieur à 35%", "Apport insuffisant",
                "Situation professionnelle instable", "Incident bancaire déclaré",
                "Reste à vivre insuffisant"]
PIECES = ["Justificatif de domicile", "Avis d'imposition N-1", "Bulletins de salaire",
          "Relevés bancaires 3 mois", "Pièce d'identité", "Attestation employeur"]


class Etat:
    def __init__(self):
        print("\n📖 Chargement de l'état depuis Bronze…")

        # ---- Référentiels fixes ----
        self.agences = read_bronze("src_agences_regions")
        self.conseillers = read_bronze("src_conseillers")
        self.partenaires = read_bronze("src_partenaires_patrimoine")
        self.produits = read_bronze("src_produits_investissement")

        if len(self.conseillers) == 0:
            raise RuntimeError("Référentiels absents — exécuter NB_00_Bootstrap.")

        # ---- Référentiels mutables : dernière version par clé ----
        prog = derniere_version(read_bronze("src_programmes_immobiliers"), "programme_id")
        lots = derniere_version(read_bronze("src_lots_immobiliers"), "lot_id")

        self.programmes = {r["programme_id"]: dict(r) for _, r in prog.iterrows()}
        self.lots = {r["lot_id"]: dict(r) for _, r in lots.iterrows()}

        # ---- Transactionnel : dernière version par clé ----
        self.prospects = self._charger("src_crm_prospects", "prospect_id", "last_update_date")
        self.investisseurs = self._charger("src_crm_investisseurs", "investisseur_id", "last_update_date")
        self.reservations = self._charger("src_reservations_immobilieres", "reservation_id")
        self.ventes = self._charger("src_ventes_immobilieres", "vente_id")
        self.financements = self._charger("src_financements", "financement_id")
        self.dossiers = self._charger("src_dossiers_adv", "dossier_adv_id")
        self.commissions = self._charger("src_commissions", "commission_id")
        self.souscriptions = self._charger("src_souscriptions_pierre_papier", "souscription_id")
        self.crowd = self._charger("src_operations_crowdfunding", "operation_crowdfunding_id")
        self.gestion = self._charger("src_gestion_locative", "gestion_id")
        self.lmnp = self._charger("src_expertise_comptable_lmnp", "dossier_comptable_id")
        self.revente = self._charger("src_revente_biens", "revente_id")
        self.reclamations = self._charger("src_reclamations_incidents", "reclamation_id")

        # ---- Index réseau ----
        ag_ville = dict(zip(self.agences["agence_id"], self.agences["ville"]))
        ag_region = dict(zip(self.agences["agence_id"], self.agences["region_id"]))
        ag_nomregion = dict(zip(self.agences["agence_id"], self.agences["nom_region"]))

        self.conseillers["_ville"] = self.conseillers["agence_id"].map(ag_ville)
        self.cons_par_ville = {v: g["conseiller_id"].tolist()
                               for v, g in self.conseillers.groupby("_ville") if len(g)}
        self.villes = sorted(self.cons_par_ville)
        self.poids_ville = [len(self.cons_par_ville[v]) for v in self.villes]

        self.cons_to_agence = dict(zip(self.conseillers["conseiller_id"], self.conseillers["agence_id"]))
        self.cons_to_region = {c: ag_region.get(a) for c, a in self.cons_to_agence.items()}
        self.ville_to_region = {}
        self.ville_to_nomregion = {}
        for _, r in self.agences.iterrows():
            self.ville_to_region[r["ville"]] = r["region_id"]
            self.ville_to_nomregion[r["ville"]] = r["nom_region"]

        self.partenaires_ids = self.partenaires["partenaire_id"].dropna().tolist()
        self.produits_ids = self.produits["produit_id"].dropna().tolist()
        self.produits_idx = {r["produit_id"]: dict(r) for _, r in self.produits.iterrows()}

        # ---- Pools dérivés : aucune table nouvelle, on reprend les IDs en base ----
        soc = self.produits["societe_gestion_id"].dropna().unique().tolist() if "societe_gestion_id" in self.produits else []
        self.societes = sorted(soc)
        prom = set(self.produits["promoteur_id"].dropna()) if "promoteur_id" in self.produits else set()
        prom |= {r.get("promoteur_id") for r in self.programmes.values() if r.get("promoteur_id")}
        self.promoteurs = sorted(p for p in prom if p)

        # Projets crowdfunding : réutiliser ceux déjà vus, sinon en créer au fil de l'eau
        self.projets = {}
        for r in self.crowd.values():
            if r.get("projet_id"):
                self.projets[r["projet_id"]] = {
                    "nom_projet": r.get("nom_projet"), "promoteur_id": r.get("promoteur_id"),
                    "ville": r.get("ville"), "region": r.get("region"),
                }

        # ---- Ensembles dérivés ----
        self.lots_dispo = {k for k, r in self.lots.items() if r.get("statut_lot") == "DISPONIBLE"}
        self.prospects_convertis = {r["prospect_id"] for r in self.investisseurs.values() if r.get("prospect_id")}

        self.agenda = defaultdict(list)
        self.compteurs = defaultdict(int)

        print(f"   {len(self.conseillers)} conseillers · {len(self.villes)} villes · "
              f"{len(self.lots)} lots ({len(self.lots_dispo)} dispo) · {len(self.programmes)} programmes")
        print(f"   {len(self.prospects)} prospects · {len(self.investisseurs)} investisseurs · "
              f"{len(self.ventes)} ventes · {len(self.societes)} sociétés · {len(self.promoteurs)} promoteurs")

    def _charger(self, table, cle, horodatage="updated_at"):
        pdf = derniere_version(read_bronze(table), cle, horodatage)
        return {r[cle]: dict(r) for _, r in pdf.iterrows()} if len(pdf) else {}

    # ---- Agenda ----
    def planifier(self, d, fn, *args):
        self.agenda[jour_ouvre_suivant(d)].append((fn, args))

    def executer(self, d):
        for fn, args in self.agenda.pop(d, []):
            fn(self, d, *args)

    # ---- Émission d'une version ----
    def maj(self, table, rec, d, **ch):
        """Émet une nouvelle version. Le CRM réécrit la ligne entière ;
        seul le nom de l'horodatage de modification change selon la table."""
        champ = ch.pop("_champ", "updated_at")
        rec.update(ch)
        rec[champ] = ts(d)
        emettre(table, rec, d)

    # ---- Sélecteurs ----
    def conseiller_de_ville(self, ville):
        pool = self.cons_par_ville.get(ville) or self.cons_par_ville[random.choice(self.villes)]
        return random.choice(pool)

    def lot_pour(self, region_investisseur):
        if not self.lots_dispo:
            return None
        ids = list(self.lots_dispo)
        if random.random() < AFFINITE_REGIONALE and region_investisseur:
            locaux = [i for i in ids
                      if self.ville_to_region.get(self.programmes.get(self.lots[i]["programme_id"], {}).get("ville")) == region_investisseur]
            if locaux:
                return self.lots[random.choice(locaux)]
        return self.lots[random.choice(ids)]

# CELL ********************

# ============================================================
# MACHINE À ÉTATS
# ============================================================

# ---------- PROSPECTS ----------

def creer_prospects(e, d):
    n = max(1, int(random.randint(*PROSPECTS_PAR_JOUR) * saisonnalite(d)))
    for _ in range(n):
        ville = random.choices(e.villes, weights=e.poids_ville)[0]
        cons = e.conseiller_de_ville(ville)
        prenom, nom = fake.first_name(), fake.last_name()
        pid = gen_id("PROS")
        rec = {
            "prospect_id": pid, "civilite": random.choice(["M.", "Mme"]),
            "nom": nom, "prenom": prenom,
            "email": f"{prenom.lower()}.{nom.lower()}@{random.choice(['gmail.com','outlook.fr','yahoo.fr','free.fr'])}".replace(" ", "-"),
            "telephone": fake.phone_number() if random.random() > 0.05 else None,
            "date_naissance": fake.date_of_birth(minimum_age=28, maximum_age=68),
            "ville": ville, "code_postal": fake.postcode(), "pays": "France",
            "situation_familiale": random.choice(["Célibataire", "Marié(e)", "Divorcé(e)", "Pacsé(e)", "Veuf(ve)"]),
            "profession": fake.job(),
            "revenu_annuel_estime": round(random.uniform(38000, 280000), 2),
            "patrimoine_estime": round(random.uniform(20000, 1800000), 2) if random.random() > 0.08 else None,
            "capacite_investissement": round(random.uniform(15000, 450000), 2),
            "objectif_investissement": random.choice(["Défiscalisation", "Revenus Complémentaires", "Retraite", "Transmission", "Plus-Value"]),
            "horizon_investissement": random.choice(["Court terme (< 2 ans)", "Moyen terme (2-5 ans)", "Long terme (> 5 ans)"]),
            "appetence_risque": random.choice(["Prudent", "Équilibré", "Dynamique", "Offensif"]),
            "source_acquisition": random.choices(
                ["Partenaire", "Web", "Recommandation", "Événement", "Publicité", "Cold Call"],
                weights=[0.25, 0.30, 0.15, 0.08, 0.14, 0.08])[0],
            "campagne_marketing": f"CAMP-{d.year}-{d.month:02d}" if random.random() > 0.35 else None,
            "canal_acquisition": random.choice(["Digital", "Téléphone", "Physique", "Email", "Réseaux Sociaux"]),
            "statut_prospect": "NOUVEAU", "score_qualification": random.randint(1, 100),
            "date_creation": d, "created_by": cons,
            "last_update_date": ts(d), "last_updated_by": cons, "is_deleted": 0,
        }
        e.prospects[pid] = rec
        emettre("src_crm_prospects", rec, d)


def avancer_prospects(e, d):
    """Le funnel CRM avance par tirage quotidien : durées de séjour exponentielles."""
    for pid, r in list(e.prospects.items()):
        st = r["statut_prospect"]
        if st in ("PERDU", "CONVERTI") or pid in e.prospects_convertis:
            continue
        cons = r.get("created_by") or e.conseiller_de_ville(r["ville"])

        if st == "NOUVEAU" and random.random() < P_CONTACTE:
            e.maj("src_crm_prospects", r, d, _champ="last_update_date",
                  statut_prospect="CONTACTE", last_updated_by=cons)
        elif st == "CONTACTE":
            if random.random() < P_PERDU:
                e.maj("src_crm_prospects", r, d, _champ="last_update_date",
                      statut_prospect="PERDU", last_updated_by=cons)
            elif random.random() < P_QUALIFIE:
                e.maj("src_crm_prospects", r, d, _champ="last_update_date",
                      statut_prospect="QUALIFIE", last_updated_by=cons,
                      score_qualification=random.randint(45, 100))
        elif st == "QUALIFIE" and random.random() < P_CHAUD:
            e.maj("src_crm_prospects", r, d, _champ="last_update_date",
                  statut_prospect="CHAUD", last_updated_by=cons,
                  score_qualification=random.randint(70, 100))


# ---------- INVESTISSEURS ----------

def convertir_prospects(e, d):
    chauds = [r for pid, r in e.prospects.items()
              if r["statut_prospect"] == "CHAUD" and pid not in e.prospects_convertis]
    for r in chauds:
        if random.random() >= P_CONVERSION:
            continue
        cons = r.get("created_by") or e.conseiller_de_ville(r["ville"])
        iid = gen_id("INV")
        inv = {
            "investisseur_id": iid, "prospect_id": r["prospect_id"], "civilite": r["civilite"],
            "nom": r["nom"], "prenom": r["prenom"], "email": r["email"], "telephone": r["telephone"],
            "adresse": fake.street_address(), "ville": r["ville"], "code_postal": r["code_postal"],
            "pays": "France", "profession": r["profession"], "situation_familiale": r["situation_familiale"],
            "revenu_annuel": r["revenu_annuel_estime"], "patrimoine_financier": r["patrimoine_estime"],
            "patrimoine_immobilier": round(random.uniform(0, 3500000), 2) if random.random() > 0.10 else None,
            "profil_investisseur": r["appetence_risque"],
            "objectif_principal": r["objectif_investissement"],
            "horizon_placement": r["horizon_investissement"],
            "niveau_experience": random.choices(["Débutant", "Intermédiaire", "Expérimenté"], weights=[0.45, 0.40, 0.15])[0],
            "statut_kyc": "EN_COURS",
            "statut_lcbft": random.choices(["CONFORME", "A_VERIFIER", "BLOQUE"], weights=[0.92, 0.06, 0.02])[0],
            "date_entree_relation": d,
            "partenaire_id": random.choice(e.partenaires_ids) if random.random() > 0.62 else None,
            "conseiller_id": cons, "agence_id": e.cons_to_agence[cons],
            "statut_client": "PROSPECT_CHAUD", "date_creation": d, "created_by": cons,
            "last_update_date": ts(d), "last_updated_by": cons, "is_deleted": 0,
        }
        e.investisseurs[iid] = inv
        e.prospects_convertis.add(r["prospect_id"])
        emettre("src_crm_investisseurs", inv, d)

        e.maj("src_crm_prospects", r, d, _champ="last_update_date",
              statut_prospect="CONVERTI", last_updated_by=cons)
        e.planifier(apres(d, KYC_DELAI), kyc_resultat, iid)


def kyc_resultat(e, d, iid):
    inv = e.investisseurs.get(iid)
    if not inv:
        return
    if random.random() < TAUX_KYC_REFUSE:
        e.maj("src_crm_investisseurs", inv, d, _champ="last_update_date",
              statut_kyc="REFUSE", statut_client="CLIENT_INACTIF")
    else:
        e.maj("src_crm_investisseurs", inv, d, _champ="last_update_date",
              statut_kyc="VALIDE", statut_client="CLIENT_ACTIF")


# ---------- RÉSERVATIONS ----------

def creer_reservations(e, d):
    eligibles = [i for i in e.investisseurs.values() if i.get("statut_kyc") == "VALIDE"]
    if not eligibles or not e.lots_dispo:
        return
    n = max(0, int(random.randint(3, 6) * saisonnalite(d)))
    for _ in range(min(n, len(e.lots_dispo))):
        inv = random.choice(eligibles)
        region = e.ville_to_region.get(inv["ville"])
        lot = e.lot_pour(region)
        if lot is None:
            break

        cons = inv["conseiller_id"]
        prix = _num(lot.get("prix_final"), 250000)
        mode = random.choices(["Crédit", "Comptant", "Mixte"], weights=[0.72, 0.10, 0.18])[0]
        rid = gen_id("RES")

        rec = {
            "reservation_id": rid, "lot_id": lot["lot_id"], "programme_id": lot["programme_id"],
            "investisseur_id": inv["investisseur_id"], "partenaire_id": inv.get("partenaire_id"),
            "conseiller_id": cons, "agence_id": e.cons_to_agence.get(cons),
            "date_reservation": d,
            "montant_reservation": round(prix * random.uniform(0.02, 0.05), 2),
            "prix_reserve": round(prix, 2),
            "remise_appliquee": round(prix * random.uniform(0, 0.03), 2) if random.random() > 0.4 else None,
            "statut_reservation": "EN_ATTENTE", "motif_annulation": None, "date_annulation": None,
            "date_expiration_reservation": d + timedelta(days=90),
            "canal_reservation": random.choice(["Agence", "Web", "Partenaire", "Téléphone", "Événement"]),
            "mode_financement_prevu": mode,
            "apport_prevu": round(prix * random.uniform(0.10, 0.40), 2),
            "montant_credit_prevu": 0.0 if mode == "Comptant" else round(prix * random.uniform(0.60, 0.90), 2),
            "commentaire_commercial": fake.sentence() if random.random() > 0.7 else None,
            "created_at": ts(d), "updated_at": ts(d), "is_deleted": 0,
        }
        e.reservations[rid] = rec
        emettre("src_reservations_immobilieres", rec, d)

        # Le lot change d'état : nouvelle version, pas d'UPDATE
        e.lots_dispo.discard(lot["lot_id"])
        e.maj("src_lots_immobiliers", lot, d, statut_lot="RESERVE", date_reservation=d,
              investisseur_id=inv["investisseur_id"], partenaire_id=inv.get("partenaire_id"))
        stock_programme(e, d, lot["programme_id"], -1)

        e.planifier(d + timedelta(days=DELAI_RETRACTATION_SRU), resa_issue, rid)


def stock_programme(e, d, programme_id, delta):
    """Le programme publie son nombre de lots disponibles. Il bouge quand un lot
    quitte ou revient dans le stock — donc à la réservation, pas à la vente."""
    prog = e.programmes.get(programme_id)
    if not prog:
        return
    reste = max(0, _int(prog.get("nombre_lots_disponibles")) + delta)
    ch = {"nombre_lots_disponibles": reste}
    statut = prog.get("statut_programme")
    if reste == 0 and statut == "EN_COMMERCIALISATION":
        ch["statut_programme"] = "COMMERCIALISE"
    elif reste > 0 and statut == "COMMERCIALISE":
        ch["statut_programme"] = "EN_COMMERCIALISATION"
    e.maj("src_programmes_immobiliers", prog, d, **ch)


def liberer_lot(e, d, lot_id):
    lot = e.lots.get(lot_id)
    if not lot:
        return
    e.lots_dispo.add(lot_id)
    e.maj("src_lots_immobiliers", lot, d, statut_lot="DISPONIBLE", date_reservation=None,
          date_vente=None, investisseur_id=None, partenaire_id=None)
    stock_programme(e, d, lot["programme_id"], +1)


def resa_issue(e, d, rid):
    """Fin du délai de rétractation SRU (10 j, art. L271-1 CCH)."""
    r = e.reservations.get(rid)
    if not r or r["statut_reservation"] != "EN_ATTENTE":
        return
    if random.random() < 0.08:
        e.maj("src_reservations_immobilieres", r, d, statut_reservation="ANNULEE",
              motif_annulation="Rétractation dans le délai légal", date_annulation=d)
        liberer_lot(e, d, r["lot_id"])
        return

    e.maj("src_reservations_immobilieres", r, d, statut_reservation="CONFIRMEE")
    if r["mode_financement_prevu"] == "Comptant":
        e.planifier(apres(d, (10, 20, 40)), creer_vente, rid, None)
    else:
        e.planifier(apres(d, FIN_DEMANDE), creer_financement, rid)


# ---------- FINANCEMENTS ----------

def creer_financement(e, d, rid):
    r = e.reservations.get(rid)
    if not r or r["statut_reservation"] != "CONFIRMEE":
        return
    fid = gen_id("FIN")
    montant = _num(r["montant_credit_prevu"])
    duree = random.choice([180, 240, 300, 360])
    taux = round(random.uniform(0.0210, 0.0455), 4)

    rec = {
        "financement_id": fid, "vente_id": None, "investisseur_id": r["investisseur_id"],
        "banque": random.choice(BANQUES), "courtier": random.choice(COURTIERS),
        "montant_demande": round(montant, 2), "montant_accorde": None,
        "taux_credit": taux, "duree_credit_mois": duree,
        "mensualite_estimee": round(montant * (taux / 12) / (1 - (1 + taux / 12) ** -duree), 2) if montant > 0 else 0.0,
        "statut_financement": "DEMANDE", "date_demande": d,
        "date_accord_principe": None, "date_offre_pret": None, "date_acceptation_offre": None,
        "motif_refus": None, "apport_personnel": r["apport_prevu"],
        "assurance_emprunteur": round(random.uniform(0.0020, 0.0055), 4),
        "created_at": ts(d), "updated_at": ts(d), "is_deleted": 0,
    }
    e.financements[fid] = rec
    emettre("src_financements", rec, d)
    e.planifier(apres(d, FIN_ACCORD), fin_accord, fid, rid)


def fin_accord(e, d, fid, rid):
    f = e.financements.get(fid)
    if not f:
        return
    if random.random() < TAUX_REFUS_PRET:
        e.maj("src_financements", f, d, statut_financement="REFUSE",
              motif_refus=random.choice(MOTIFS_REFUS))
        r = e.reservations.get(rid)
        if r and r["statut_reservation"] == "CONFIRMEE":
            e.maj("src_reservations_immobilieres", r, d, statut_reservation="ANNULEE",
                  motif_annulation="Condition suspensive de prêt non levée", date_annulation=d)
            liberer_lot(e, d, r["lot_id"])
        return

    e.maj("src_financements", f, d, statut_financement="ACCORD_PRINCIPE",
          date_accord_principe=d, montant_accorde=f["montant_demande"])
    e.planifier(apres(d, FIN_OFFRE), fin_offre, fid, rid)


def fin_offre(e, d, fid, rid):
    f = e.financements.get(fid)
    if not f:
        return
    e.maj("src_financements", f, d, statut_financement="OFFRE_EMISE", date_offre_pret=d)
    e.planifier(apres(d, FIN_ACCEPTATION), fin_acceptation, fid, rid)


def fin_acceptation(e, d, fid, rid):
    """Acceptation après les 10 j de réflexion légaux (art. L313-34 C. conso)."""
    f = e.financements.get(fid)
    if not f:
        return
    e.maj("src_financements", f, d, statut_financement="ACCEPTE", date_acceptation_offre=d)
    creer_vente(e, d, rid, fid)


# ---------- VENTES ----------

def creer_vente(e, d, rid, fid):
    r = e.reservations.get(rid)
    if not r or r["statut_reservation"] != "CONFIRMEE":
        return
    lot = e.lots.get(r["lot_id"])
    if not lot or lot.get("statut_lot") == "VENDU":
        return

    vid = gen_id("VENT")
    ttc = _num(r["prix_reserve"])
    ht = round(ttc / 1.20, 2)
    f = e.financements.get(fid) if fid else None

    rec = {
        "vente_id": vid, "reservation_id": rid, "lot_id": r["lot_id"], "programme_id": r["programme_id"],
        "investisseur_id": r["investisseur_id"], "partenaire_id": r["partenaire_id"],
        "conseiller_id": r["conseiller_id"], "agence_id": r["agence_id"],
        "date_signature_contrat": d, "date_signature_acte": None,
        "date_livraison_prevue": d + timedelta(days=tri(VENTE_LIVRAISON)),
        "date_livraison_reelle": None,
        "prix_vente_ht": ht, "prix_vente_ttc": round(ttc, 2), "tva": round(ttc - ht, 2),
        "frais_notaire": round(ttc * random.uniform(0.020, 0.035), 2),
        "montant_total_operation": round(ttc * 1.03, 2),
        "mode_financement": r["mode_financement_prevu"],
        "montant_apport": r["apport_prevu"], "montant_credit": r["montant_credit_prevu"],
        "banque_financement": f["banque"] if f else None,
        "statut_vente": "SIGNEE", "motif_echec": None,
        "created_at": ts(d), "updated_at": ts(d), "is_deleted": 0,
    }
    e.ventes[vid] = rec
    emettre("src_ventes_immobilieres", rec, d)

    if f:
        e.maj("src_financements", f, d, vente_id=vid)

    # Le lot passe VENDU
    e.maj("src_lots_immobiliers", lot, d, statut_lot="VENDU", date_vente=d,
          investisseur_id=r["investisseur_id"], partenaire_id=r["partenaire_id"])

    # Le compteur du programme a déjà été décrémenté à la réservation.
    creer_dossier_adv(e, d, vid)
    creer_commission(e, d, "VENTE_IMMOBILIER", vid)
    e.planifier(d + timedelta(days=tri(VENTE_ACTE)), vente_acte, vid)


def vente_acte(e, d, vid):
    v = e.ventes.get(vid)
    if not v:
        return
    e.maj("src_ventes_immobilieres", v, d, statut_vente="EN_COURS", date_signature_acte=d)
    liv = _dt(v["date_livraison_prevue"])
    if liv:
        e.planifier(liv + timedelta(days=random.randint(-30, 120)), vente_livraison, vid)


def vente_livraison(e, d, vid):
    v = e.ventes.get(vid)
    if not v:
        return
    e.maj("src_ventes_immobilieres", v, d, statut_vente="LIVREE", date_livraison_reelle=d)
    prog = e.programmes.get(v["programme_id"])
    if prog and not prog.get("date_livraison_reelle"):
        e.maj("src_programmes_immobiliers", prog, d, date_livraison_reelle=d, statut_programme="LIVRE")
    if random.random() < 0.55:
        e.planifier(apres(d, GL_APRES_LIVRAISON), creer_gestion, vid)

# CELL ********************

# ---------- DOSSIERS ADV ----------

def creer_dossier_adv(e, d, vid):
    v = e.ventes[vid]
    did = gen_id("ADV")
    bloque = random.random() < ADV_TAUX_BLOCAGE
    rec = {
        "dossier_adv_id": did, "vente_id": vid, "reservation_id": v["reservation_id"],
        "investisseur_id": v["investisseur_id"], "lot_id": v["lot_id"], "programme_id": v["programme_id"],
        "partenaire_id": v["partenaire_id"], "conseiller_id": v["conseiller_id"],
        "statut_dossier": "OUVERT", "date_ouverture_dossier": d,
        "date_reception_pieces": None, "date_validation_dossier": None,
        "date_envoi_notaire": None, "date_signature_acte": None,
        "delai_traitement_jours": None,
        "pieces_manquantes": ", ".join(random.sample(PIECES, random.randint(1, 3))) if bloque else None,
        "nombre_relances": 0, "blocage_adv": 1 if bloque else 0,
        "motif_blocage": "Pièces justificatives manquantes" if bloque else None,
        "responsable_adv_id": random.choice(e.cons_par_ville[random.choice(e.villes)]),
        "commentaire_adv": None,
        "created_at": ts(d), "updated_at": ts(d), "is_deleted": 0,
    }
    e.dossiers[did] = rec
    emettre("src_dossiers_adv", rec, d)
    retard = tri((10, 25, 90)) if bloque else 0
    e.planifier(apres(d + timedelta(days=retard), ADV_PIECES), adv_pieces, did)


def adv_pieces(e, d, did):
    r = e.dossiers.get(did)
    if not r:
        return
    e.maj("src_dossiers_adv", r, d, statut_dossier="PIECES_RECUES", date_reception_pieces=d,
          pieces_manquantes=None, blocage_adv=0, motif_blocage=None,
          nombre_relances=_int(r["nombre_relances"]) + (random.randint(1, 4) if _int(r["blocage_adv"]) else 0))
    e.planifier(apres(d, ADV_VALIDATION), adv_validation, did)


def adv_validation(e, d, did):
    r = e.dossiers.get(did)
    if not r:
        return
    e.maj("src_dossiers_adv", r, d, statut_dossier="VALIDE", date_validation_dossier=d)
    e.planifier(apres(d, ADV_NOTAIRE), adv_notaire, did)


def adv_notaire(e, d, did):
    r = e.dossiers.get(did)
    if not r:
        return
    e.maj("src_dossiers_adv", r, d, statut_dossier="ENVOYE_NOTAIRE", date_envoi_notaire=d)
    e.planifier(apres(d, ADV_SIGNATURE), adv_signature, did)


def adv_signature(e, d, did):
    r = e.dossiers.get(did)
    if not r:
        return
    ouv = _dt(r["date_ouverture_dossier"])
    e.maj("src_dossiers_adv", r, d, statut_dossier="SIGNE", date_signature_acte=d,
          delai_traitement_jours=(d - ouv).days if ouv else None,
          commentaire_adv="Dossier clôturé" if random.random() > 0.6 else None)


# ---------- COMMISSIONS ----------

def creer_commission(e, d, type_op, op_id):
    if type_op == "VENTE_IMMOBILIER":
        src = e.ventes[op_id]
        montant, taux = _num(src["prix_vente_ttc"]), round(random.uniform(0.020, 0.050), 4)
        ids = {"vente_id": op_id, "souscription_id": None, "operation_crowdfunding_id": None,
               "produit_id": None, "programme_id": src["programme_id"]}
    elif type_op == "SOUSCRIPTION_SCPI":
        src = e.souscriptions[op_id]
        montant, taux = _num(src["montant_souscrit"]), round(random.uniform(0.010, 0.030), 4)
        ids = {"vente_id": None, "souscription_id": op_id, "operation_crowdfunding_id": None,
               "produit_id": src["produit_id"], "programme_id": None}
    else:
        src = e.crowd[op_id]
        montant, taux = _num(src["montant_investi"]), round(random.uniform(0.005, 0.020), 4)
        ids = {"vente_id": None, "souscription_id": None, "operation_crowdfunding_id": op_id,
               "produit_id": None, "programme_id": None}

    brut = round(montant * taux, 2)
    part_p = round(brut * random.uniform(0.30, 0.50), 2) if src.get("partenaire_id") else 0.0
    cid = gen_id("COM")
    rec = {
        "commission_id": cid, "type_operation": type_op, "operation_id": op_id,
        "investisseur_id": src["investisseur_id"], "partenaire_id": src.get("partenaire_id"),
        "conseiller_id": src["conseiller_id"], "agence_id": src.get("agence_id"),
        "montant_operation": round(montant, 2), "taux_commission": taux,
        "montant_commission_brut": brut, "montant_commission_net": round(brut * 0.85, 2),
        "part_commission_partenaire": part_p, "part_commission_interne": round(brut - part_p, 2),
        "statut_commission": "EN_ATTENTE", "date_calcul": d,
        "date_validation": None, "date_paiement": None,
        "mode_paiement": random.choice(["Virement", "Chèque", "Prélèvement"]),
        "motif_blocage": None, "created_at": ts(d), "updated_at": ts(d), "is_deleted": 0,
        **ids,
    }
    e.commissions[cid] = rec
    emettre("src_commissions", rec, d)
    e.planifier(apres(d, COMM_VALIDATION), comm_validation, cid)


def comm_validation(e, d, cid):
    r = e.commissions.get(cid)
    if not r:
        return
    if random.random() < COMM_TAUX_BLOCAGE:
        e.maj("src_commissions", r, d, statut_commission="BLOQUEE",
              motif_blocage=random.choice(["Litige commercial", "Dossier ADV incomplet", "Contrôle conformité"]))
        return
    e.maj("src_commissions", r, d, statut_commission="VALIDEE", date_validation=d)
    e.planifier(apres(d, COMM_PAIEMENT), comm_paiement, cid)


def comm_paiement(e, d, cid):
    r = e.commissions.get(cid)
    if not r:
        return
    e.maj("src_commissions", r, d, statut_commission="PAYEE", date_paiement=d)


# ---------- SOUSCRIPTIONS PIERRE-PAPIER ----------

def creer_souscriptions(e, d):
    elig = [i for i in e.investisseurs.values() if i.get("statut_kyc") == "VALIDE"]
    if not elig or not e.produits_ids:
        return
    n = max(0, int(random.randint(3, 7) * saisonnalite(d)))
    for _ in range(n):
        inv = random.choice(elig)
        prod = e.produits_idx[random.choice(e.produits_ids)]
        cons = inv["conseiller_id"]
        montant = round(random.uniform(5000, 180000), 2)
        prix_part = round(random.uniform(150, 1100), 2)
        sid = gen_id("SOUS")
        rec = {
            "souscription_id": sid, "investisseur_id": inv["investisseur_id"],
            "partenaire_id": inv.get("partenaire_id"), "conseiller_id": cons,
            "agence_id": e.cons_to_agence.get(cons), "produit_id": prod["produit_id"],
            "societe_gestion_id": prod.get("societe_gestion_id"),
            "type_support": prod.get("famille_produit"), "nom_support": prod.get("nom_produit"),
            "date_souscription": d, "montant_souscrit": montant,
            "nombre_parts": round(montant / prix_part, 4), "prix_part": prix_part,
            "frais_souscription": round(montant * _num(prod.get("frais_entree"), 0.02), 2),
            "duree_recommandee": prod.get("duree_recommandee"),
            "rendement_previsionnel": _num(prod.get("rendement_cible_annuel"), 0.045),
            "statut_souscription": "EN_ATTENTE", "date_validation": None,
            "date_rejet": None, "motif_rejet": None,
            "mode_paiement": random.choice(["Virement", "Prélèvement", "Chèque"]),
            "created_at": ts(d), "updated_at": ts(d), "is_deleted": 0,
        }
        e.souscriptions[sid] = rec
        emettre("src_souscriptions_pierre_papier", rec, d)
        e.planifier(apres(d, (1, 5, 12)), sous_issue, sid)


def sous_issue(e, d, sid):
    r = e.souscriptions.get(sid)
    if not r:
        return
    if random.random() < 0.12:
        e.maj("src_souscriptions_pierre_papier", r, d, statut_souscription="REJETEE",
              date_rejet=d, motif_rejet=random.choice(["Dossier incomplet", "Profil de risque inadapté", "Origine des fonds non justifiée"]))
        return
    e.maj("src_souscriptions_pierre_papier", r, d, statut_souscription="VALIDEE", date_validation=d)
    creer_commission(e, d, "SOUSCRIPTION_SCPI", sid)


# ---------- CROWDFUNDING ----------

def _projet(e, d):
    if e.projets and random.random() < 0.8:
        pid = random.choice(list(e.projets))
        return pid, e.projets[pid]
    ville = random.choices(e.villes, weights=e.poids_ville)[0]
    pid = gen_id("PROJ")
    meta = {"nom_projet": f"Projet {ville} {d.year}-{random.randint(1,99):02d}",
            "promoteur_id": random.choice(e.promoteurs) if e.promoteurs else None,
            "ville": ville, "region": e.ville_to_nomregion.get(ville)}
    e.projets[pid] = meta
    return pid, meta


def creer_crowdfunding(e, d):
    elig = [i for i in e.investisseurs.values() if i.get("statut_kyc") == "VALIDE"]
    if not elig:
        return
    for _ in range(max(0, int(random.randint(1, 3) * saisonnalite(d)))):
        inv = random.choice(elig)
        cons = inv["conseiller_id"]
        pid, meta = _projet(e, d)
        montant = round(random.uniform(1000, 45000), 2)
        duree = random.choice([12, 18, 24, 36])
        taux = round(random.uniform(0.060, 0.115), 4)
        oid = gen_id("CROW")
        rec = {
            "operation_crowdfunding_id": oid, "investisseur_id": inv["investisseur_id"],
            "partenaire_id": inv.get("partenaire_id"), "conseiller_id": cons,
            "agence_id": e.cons_to_agence.get(cons), "projet_id": pid,
            "nom_projet": meta["nom_projet"], "promoteur_id": meta["promoteur_id"],
            "ville": meta["ville"], "region": meta["region"],
            "date_investissement": d, "montant_investi": montant,
            "taux_rendement_annuel_prevu": taux, "duree_mois": duree,
            "statut_operation": "EN_COURS",
            "date_remboursement_prevue": d + timedelta(days=duree * 30),
            "date_remboursement_reelle": None, "montant_rembourse": None,
            "interets_bruts": None,
            "fiscalite_appliquee": random.choice(["Flat Tax", "IR", "Exonéré"]),
            "incident_paiement": 0, "created_at": ts(d), "updated_at": ts(d), "is_deleted": 0,
        }
        e.crowd[oid] = rec
        emettre("src_operations_crowdfunding", rec, d)
        e.planifier(d + timedelta(days=duree * 30), crowd_echeance, oid)


def crowd_echeance(e, d, oid):
    r = e.crowd.get(oid)
    if not r:
        return
    tirage = random.random()
    montant, taux, duree = _num(r["montant_investi"]), _num(r["taux_rendement_annuel_prevu"]), _int(r["duree_mois"])
    interets = round(montant * taux * duree / 12, 2)
    if tirage < 0.78:
        e.maj("src_operations_crowdfunding", r, d, statut_operation="REMBOURSE",
              date_remboursement_reelle=d, montant_rembourse=round(montant + interets, 2),
              interets_bruts=interets)
    elif tirage < 0.94:
        e.maj("src_operations_crowdfunding", r, d, statut_operation="EN_RETARD", incident_paiement=1)
        e.planifier(d + timedelta(days=random.randint(30, 180)), crowd_echeance, oid)
    else:
        e.maj("src_operations_crowdfunding", r, d, statut_operation="DEFAUT", incident_paiement=1,
              montant_rembourse=round(montant * random.uniform(0.0, 0.6), 2), interets_bruts=0.0)


# ---------- GESTION LOCATIVE ----------

def creer_gestion(e, d, vid):
    v = e.ventes.get(vid)
    if not v:
        return
    lot = e.lots.get(v["lot_id"], {})
    loyer = _num(lot.get("loyer_estime_mensuel"), _num(v["prix_vente_ttc"]) * 0.0035)
    gid = gen_id("GL")
    rec = {
        "gestion_id": gid, "vente_id": vid, "lot_id": v["lot_id"],
        "investisseur_id": v["investisseur_id"], "programme_id": v["programme_id"],
        "gestionnaire_id": random.choice(e.cons_par_ville[random.choice(e.villes)]),
        "date_debut_gestion": d, "date_fin_gestion": None, "statut_gestion": "ACTIVE",
        "loyer_mensuel_prevu": round(loyer, 2), "loyer_mensuel_reel": round(loyer, 2),
        "taux_occupation": 1.0, "vacance_locative_jours": 0,
        "charges_mensuelles": round(loyer * random.uniform(0.08, 0.22), 2),
        "incident_locatif": 0, "montant_impayes": 0.0,
        "rendement_reel_annuel": round(loyer * 12 / max(_num(v["prix_vente_ttc"]), 1), 4),
        "created_at": ts(d), "updated_at": ts(d), "is_active": 1,
    }
    e.gestion[gid] = rec
    emettre("src_gestion_locative", rec, d)
    e.planifier(d + timedelta(days=30), gestion_mensuelle, gid)


def gestion_mensuelle(e, d, gid):
    r = e.gestion.get(gid)
    if not r or r.get("statut_gestion") != "ACTIVE":
        return
    if random.random() < 0.008:
        e.maj("src_gestion_locative", r, d, statut_gestion="RESILIEE", date_fin_gestion=d, is_active=0)
        return

    prevu = _num(r["loyer_mensuel_prevu"])
    vacance = random.choices([0, random.randint(1, 30), random.randint(31, 90)], weights=[0.86, 0.11, 0.03])[0]
    occ = round(max(0.0, 1 - vacance / 30.0), 4) if vacance <= 30 else 0.0
    incident = 1 if random.random() < 0.06 else 0
    impayes = round(prevu * random.uniform(0.5, 3.0), 2) if incident else 0.0
    reel = round(prevu * occ, 2)
    v = e.ventes.get(r["vente_id"], {})

    e.maj("src_gestion_locative", r, d, loyer_mensuel_reel=reel, taux_occupation=occ,
          vacance_locative_jours=vacance, incident_locatif=incident, montant_impayes=impayes,
          rendement_reel_annuel=round(reel * 12 / max(_num(v.get("prix_vente_ttc")), 1), 4))
    e.planifier(d + timedelta(days=30), gestion_mensuelle, gid)


# ---------- LMNP ----------

def creer_lmnp(e, d):
    """Ouverture des dossiers fiscaux en janvier, pour l'année fiscale précédente."""
    actifs = [g for g in e.gestion.values() if g.get("statut_gestion") == "ACTIVE"]
    for g in actifs:
        if random.random() > 0.45:
            continue
        annee = d.year - 1
        if any(x["vente_id"] == g["vente_id"] and _int(x["annee_fiscale"]) == annee for x in e.lmnp.values()):
            continue
        recettes = round(_num(g["loyer_mensuel_reel"]) * 12, 2)
        charges = round(recettes * random.uniform(0.15, 0.35), 2)
        amort = round(_num(e.ventes.get(g["vente_id"], {}).get("prix_vente_ttc")) * random.uniform(0.020, 0.033), 2)
        resultat = round(recettes - charges - amort, 2)
        did = gen_id("LMNP")
        rec = {
            "dossier_comptable_id": did, "investisseur_id": g["investisseur_id"],
            "vente_id": g["vente_id"], "lot_id": g["lot_id"], "programme_id": g["programme_id"],
            "annee_fiscale": annee,
            "regime_fiscal": random.choices(["LMNP Réel", "LMNP Micro-BIC"], weights=[0.7, 0.3])[0],
            "statut_dossier_comptable": "OUVERT", "date_ouverture": d,
            "date_reception_documents": None, "date_declaration": None,
            "recettes_locatives": recettes, "charges_deductibles": charges,
            "amortissements": amort, "resultat_fiscal": resultat,
            "impot_estime": round(max(0.0, resultat) * 0.30, 2),
            "comptable_id": random.choice(e.cons_par_ville[random.choice(e.villes)]),
            "nombre_relances": 0, "pieces_manquantes": None,
            "created_at": ts(d), "updated_at": ts(d), "is_deleted": 0,
        }
        e.lmnp[did] = rec
        emettre("src_expertise_comptable_lmnp", rec, d)
        e.planifier(apres(d, (15, 45, 90)), lmnp_reception, did)


def lmnp_reception(e, d, did):
    r = e.lmnp.get(did)
    if not r:
        return
    manque = random.random() < 0.25
    e.maj("src_expertise_comptable_lmnp", r, d, statut_dossier_comptable="DOCUMENTS_RECUS",
          date_reception_documents=d,
          pieces_manquantes=", ".join(random.sample(PIECES, 2)) if manque else None,
          nombre_relances=_int(r["nombre_relances"]) + (random.randint(1, 3) if manque else 0))
    cible = date(d.year, 5, random.randint(2, 28))
    e.planifier(cible if cible > d else apres(d, (10, 20, 40)), lmnp_declaration, did)


def lmnp_declaration(e, d, did):
    r = e.lmnp.get(did)
    if not r:
        return
    e.maj("src_expertise_comptable_lmnp", r, d, statut_dossier_comptable="DECLARE",
          date_declaration=d, pieces_manquantes=None)


# ---------- REVENTE ----------

def creer_revente(e, d):
    """Revente sur le marché secondaire : biens livrés depuis > 2 ans."""
    candidats = [v for v in e.ventes.values()
                 if v.get("statut_vente") == "LIVREE"
                 and _dt(v.get("date_livraison_reelle"))
                 and (d - _dt(v["date_livraison_reelle"])).days > 730
                 and not any(x["vente_id"] == v["vente_id"] for x in e.revente.values())]
    if not candidats or random.random() > 0.12:
        return
    v = random.choice(candidats)
    achat = _num(v["prix_vente_ttc"])
    estime = round(achat * random.uniform(0.92, 1.35), 2)
    rid = gen_id("REV")
    rec = {
        "revente_id": rid, "vente_id": v["vente_id"], "lot_id": v["lot_id"],
        "investisseur_id": v["investisseur_id"], "programme_id": v["programme_id"],
        "date_demande_revente": d, "date_mise_en_marche": None, "date_revente": None,
        "prix_achat_initial": round(achat, 2), "prix_revente_estime": estime,
        "prix_revente_final": None, "plus_value_brute": None, "plus_value_nette": None,
        "statut_revente": "DEMANDE",
        "motif_revente": random.choice(["Arbitrage patrimonial", "Besoin de liquidités", "Changement de situation", "Prise de plus-value"]),
        "mandat_revente": random.choice(["Simple", "Exclusif"]),
        "conseiller_revente_id": v["conseiller_id"], "nombre_visites": 0,
        "created_at": ts(d), "updated_at": ts(d), "is_deleted": 0,
    }
    e.revente[rid] = rec
    emettre("src_revente_biens", rec, d)
    e.planifier(apres(d, (10, 25, 60)), revente_marche, rid)


def revente_marche(e, d, rid):
    r = e.revente.get(rid)
    if not r:
        return
    e.maj("src_revente_biens", r, d, statut_revente="EN_VENTE", date_mise_en_marche=d)
    e.planifier(apres(d, (60, 150, 400)), revente_conclusion, rid)


def revente_conclusion(e, d, rid):
    r = e.revente.get(rid)
    if not r:
        return
    if random.random() < 0.15:
        e.maj("src_revente_biens", r, d, statut_revente="RETIREE", nombre_visites=random.randint(0, 12))
        return
    achat, estime = _num(r["prix_achat_initial"]), _num(r["prix_revente_estime"])
    final = round(estime * random.uniform(0.90, 1.04), 2)
    brute = round(final - achat, 2)
    e.maj("src_revente_biens", r, d, statut_revente="VENDUE", date_revente=d,
          prix_revente_final=final, plus_value_brute=brute,
          plus_value_nette=round(brute * (0.664 if brute > 0 else 1.0), 2),
          nombre_visites=random.randint(3, 30))


# ---------- RÉCLAMATIONS ----------

def creer_reclamations(e, d):
    if random.random() > RECLA_PROBA_JOUR:
        return
    sources = [("VENTE_IMMOBILIER", e.ventes), ("SOUSCRIPTION_SCPI", e.souscriptions),
               ("CROWDFUNDING", e.crowd)]
    sources = [(t, m) for t, m in sources if m]
    if not sources:
        return
    for _ in range(random.randint(1, 3)):
        type_op, mapping = random.choice(sources)
        op_id = random.choice(list(mapping))
        src = mapping[op_id]
        rid = gen_id("RECLA")
        rec = {
            "reclamation_id": rid, "investisseur_id": src["investisseur_id"],
            "partenaire_id": src.get("partenaire_id"), "operation_id": op_id,
            "type_operation": type_op,
            "type_reclamation": random.choice(["Délai", "Qualité", "Commercial", "Administratif", "Financier"]),
            "categorie_reclamation": random.choices(["Mineure", "Majeure", "Critique"], weights=[0.6, 0.32, 0.08])[0],
            "niveau_urgence": random.choices(["FAIBLE", "MOYEN", "ELEVE", "CRITIQUE"], weights=[0.35, 0.4, 0.2, 0.05])[0],
            "statut_reclamation": "OUVERTE", "date_ouverture": d,
            "date_resolution": None, "delai_resolution_jours": None,
            "responsable_traitement_id": src.get("conseiller_id"),
            "motif_reclamation": fake.sentence(), "resolution_apportee": None,
            "impact_financier_estime": round(random.uniform(0, 40000), 2) if random.random() > 0.55 else None,
            "created_at": ts(d), "updated_at": ts(d), "is_deleted": 0,
        }
        e.reclamations[rid] = rec
        emettre("src_reclamations_incidents", rec, d)
        e.planifier(apres(d, RECLA_RESOLUTION), recla_resolution, rid)


def recla_resolution(e, d, rid):
    r = e.reclamations.get(rid)
    if not r:
        return
    ouv = _dt(r["date_ouverture"])
    e.maj("src_reclamations_incidents", r, d, statut_reclamation="RESOLUE", date_resolution=d,
          delai_resolution_jours=(d - ouv).days if ouv else None,
          resolution_apportee=fake.sentence())
    e.planifier(apres(d, (3, 8, 20)), recla_cloture, rid)


def recla_cloture(e, d, rid):
    r = e.reclamations.get(rid)
    if not r:
        return
    e.maj("src_reclamations_incidents", r, d, statut_reclamation="CLOTUREE")


# ---------- ÉVÉNEMENTS (log immuable) ----------

def creer_evenements(e, d):
    pool = [("P", p) for p, r in e.prospects.items() if r["statut_prospect"] not in ("PERDU",)]
    pool += [("I", i) for i in e.investisseurs]
    if not pool:
        return
    n = max(1, int(random.randint(20, 45) * saisonnalite(d)))
    for _ in range(n):
        kind, cid = random.choice(pool)
        base = e.prospects[cid] if kind == "P" else e.investisseurs[cid]
        cons = base.get("created_by") or base.get("conseiller_id") or e.conseiller_de_ville(base["ville"])
        eid = gen_id("EVT")
        rec = {
            "evenement_id": eid,
            "investisseur_id": cid if kind == "I" else None,
            "prospect_id": cid if kind == "P" else None,
            "partenaire_id": base.get("partenaire_id"),
            "conseiller_id": cons,
            "type_evenement": random.choice(["Appel Entrant", "Appel Sortant", "Email", "RDV Physique", "Visioconférence", "SMS"]),
            "canal_evenement": random.choice(["Téléphone", "Email", "Physique", "Digital", "Courrier"]),
            "objet_evenement": fake.sentence(), "date_evenement": d,
            "statut_evenement": random.choices(["REALISE", "PLANIFIE", "ANNULE"], weights=[0.72, 0.23, 0.05])[0],
            "resultat_evenement": random.choice(["Intéressé", "Pas Intéressé", "À Rappeler", "Dossier Ouvert", "RDV Pris"]),
            "prochaine_action": fake.sentence() if random.random() > 0.5 else None,
            "date_prochaine_action": d + timedelta(days=random.randint(1, 30)) if random.random() > 0.5 else None,
            "priorite": random.choices(["HAUTE", "NORMALE", "BASSE"], weights=[0.2, 0.6, 0.2])[0],
            "commentaire": fake.paragraph() if random.random() > 0.6 else None,
            "created_at": ts(d), "created_by": cons, "updated_at": ts(d), "is_deleted": 0,
        }
        emettre("src_evenements_clients", rec, d)


# ---------- RENOUVELLEMENT DU STOCK ----------

TYPOLOGIES = ["T1", "T2", "T3", "T4", "T5"]
ORIENTATIONS = ["Nord", "Sud", "Est", "Ouest", "Nord-Est", "Sud-Ouest"]


def renouvellement(e, d):
    if not RENOUVELLEMENT_TRIMESTRIEL or d.month not in (1, 4, 7, 10) or d.day > 3:
        return
    if e.compteurs[f"renouv-{d.year}-{d.month}"]:
        return
    e.compteurs[f"renouv-{d.year}-{d.month}"] = 1

    for _ in range(random.randint(*NB_NOUVEAUX_PROGRAMMES)):
        ville = random.choices(e.villes, weights=e.poids_ville)[0]
        nb = random.randint(12, 55)
        prix_m2 = round(random.uniform(2600, 11500), 2)
        pid = gen_id("PROG")
        prog = {
            "programme_id": pid, "nom_programme": f"Résidence {fake.last_name()} - {ville}",
            "type_programme": random.choice(["Résidentiel", "Commercial", "Mixte"]),
            "promoteur_id": random.choice(e.promoteurs) if e.promoteurs else None,
            "ville": ville, "code_postal": fake.postcode(),
            "region": e.ville_to_nomregion.get(ville), "adresse": fake.street_address(),
            "latitude": round(random.uniform(43.0, 50.8), 6), "longitude": round(random.uniform(-1.6, 7.5), 6),
            "type_actif": random.choice(["Appartement", "Bureau", "Commerce", "Résidence Services"]),
            "segment_marche": random.choice(["Premium", "Standard", "Accessible"]),
            "statut_programme": "EN_COMMERCIALISATION",
            "date_lancement_commercial": d,
            "date_livraison_prevue": d + timedelta(days=random.randint(400, 1100)),
            "date_livraison_reelle": None,
            "nombre_lots_total": nb, "nombre_lots_disponibles": nb, "prix_moyen_m2": prix_m2,
            "rentabilite_cible": round(random.uniform(0.025, 0.060), 4),
            "zone_fiscale": random.choice(["A bis", "A", "B1", "B2"]),
            "dispositif_fiscal": random.choice(["Pinel", "LMNP", "Malraux", "Déficit Foncier", "Nue-Propriété"]),
            "label_energetique": random.choice(["BBC", "HQE", "RT2012", "RE2020"]),
            "note_programme": random.randint(1, 10),
            "created_at": ts(d), "updated_at": ts(d), "is_active": 1,
        }
        e.programmes[pid] = prog
        emettre("src_programmes_immobiliers", prog, d)

        for j in range(nb):
            surface = round(random.uniform(24, 118), 2)
            cat = round(surface * prix_m2 * random.uniform(0.90, 1.12), 2)
            remise = round(cat * random.uniform(0, 0.05), 2)
            lid = gen_id("LOT")
            lot = {
                "lot_id": lid, "programme_id": pid, "numero_lot": f"{pid[-4:]}-{j+1:03d}",
                "type_lot": random.choice(["Appartement", "Studio", "Duplex", "Penthouse"]),
                "typologie": random.choice(TYPOLOGIES), "surface_m2": surface,
                "etage": random.randint(0, 12), "orientation": random.choice(ORIENTATIONS),
                "parking_inclus": random.choice([0, 1]),
                "prix_catalogue": cat, "prix_remise": remise, "prix_final": round(cat - remise, 2),
                "loyer_estime_mensuel": round(cat * random.uniform(0.0025, 0.0045), 2),
                "rentabilite_brute_estimee": round(random.uniform(0.020, 0.070), 4),
                "statut_lot": "DISPONIBLE", "date_disponibilite": d,
                "date_reservation": None, "date_vente": None,
                "investisseur_id": None, "partenaire_id": None,
                "created_at": ts(d), "updated_at": ts(d), "is_active": 1,
            }
            e.lots[lid] = lot
            e.lots_dispo.add(lid)
            emettre("src_lots_immobiliers", lot, d)

# CELL ********************

# ============================================================
# BOUCLE QUOTIDIENNE
# ============================================================


def journee(e, d):
    e.executer(d)                 # 1. faire avancer les dossiers déjà ouverts
    renouvellement(e, d)          # 2. nouveaux programmes (trimestriel)

    if d.month == 1 and not e.compteurs[f"lmnp-{d.year}"]:
        e.compteurs[f"lmnp-{d.year}"] = 1
        creer_lmnp(e, d)          # 3. campagne fiscale annuelle

    creer_prospects(e, d)         # 4. seul flux exogène
    avancer_prospects(e, d)
    convertir_prospects(e, d)
    creer_reservations(e, d)
    creer_souscriptions(e, d)
    creer_crowdfunding(e, d)
    creer_revente(e, d)
    creer_reclamations(e, d)
    creer_evenements(e, d)


if A_TRAITER:
    etat = Etat()
    print(f"\n▶️  Simulation de {A_TRAITER[0]} à {A_TRAITER[-1]}\n")

    for i, d in enumerate(A_TRAITER, 1):
        journee(etat, d)
        if i % 100 == 0 or i == len(A_TRAITER):
            print(f"   … {i}/{len(A_TRAITER)} jours — {sum(len(v) for v in BUS.buffer.values()):,} versions émises")

# CELL ********************

# ============================================================
# ÉCRITURE BRONZE
# ------------------------------------------------------------
# Tout en varchar, comme la source. APPEND uniquement.
# Une même clé peut apparaître N fois : c'est le principe du CDC.
# Le typage et le dédoublonnage sont la responsabilité de Silver.
# ============================================================


def ecrire(table, records):
    if not records:
        return 0
    cols = COLS[table]
    data = [tuple(s(r[c]) for c in cols) for r in records]
    schema = StructType([StructField(c, StringType(), True) for c in cols])

    if MODE == "dry_run":
        print(f"   [dry_run] {table:36s} {len(data):>8,} versions")
        return len(data)

    sdf = spark.createDataFrame(data, schema=schema)
    sdf.write.mode("append").format("delta").option("mergeSchema", "true") \
       .saveAsTable(f"dbo.{table}")
    return len(data)


if A_TRAITER:
    print("\n💾 Écriture Bronze (append de versions)\n")
    total = 0
    for table in sorted(BUS.buffer):
        n = ecrire(table, BUS.buffer[table])
        total += n
        cles = len({r[COLS[table][0]] for r in BUS.buffer[table]})
        print(f"   ✅ {table:36s} {n:>8,} versions  ({cles:,} clés distinctes)")

    if MODE == "append":
        spark.sql("""
            CREATE TABLE IF NOT EXISTS dbo.tech_simulation_run_log (
                date_cible DATE, table_cible STRING, nb_versions BIGINT,
                run_timestamp TIMESTAMP, run_mode STRING
            ) USING DELTA
        """)
        agg = defaultdict(int)
        for d, t in BUS.journal:
            agg[(d, t)] += 1
        now = datetime.now()
        rows = [(d, t, n, now, MODE) for (d, t), n in agg.items()]
        log_schema = StructType([
            StructField("date_cible", DateType()), StructField("table_cible", StringType()),
            StructField("nb_versions", LongType()), StructField("run_timestamp", TimestampType()),
            StructField("run_mode", StringType()),
        ])
        spark.createDataFrame(rows, schema=log_schema).write.mode("append").format("delta") \
             .saveAsTable("dbo.tech_simulation_run_log")
        print(f"   ✅ {'tech_simulation_run_log':36s} {len(rows):>8,} lignes")

    print(f"""
{'=' * 74}
✅ Terminé — {A_TRAITER[0]} → {A_TRAITER[-1]} · {len(A_TRAITER)} jours ouvrés · {total:,} versions

   Bronze est append-only. Chaque changement d'état = une nouvelle ligne.
   Silver doit dédoublonner : dernière version par clé, ordonnée par updated_at.
{'=' * 74}
""")

# METADATA ********************

# META {"language": "python", "language_group": "synapse_pyspark"}

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from datetime import date, timedelta
print(date.today())
print(date.today() - timedelta(days=1))
print(est_ouvre(date.today() - timedelta(days=1)))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

spark.table("dbo.src_conseillers").count()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from datetime import date, timedelta
print(date.today())
print(date.today() - timedelta(days=1))
print(est_ouvre(date.today() - timedelta(days=1)))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
