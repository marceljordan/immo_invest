# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "warehouse": {
# META       "default_warehouse": "04eb4206-5c5f-46fe-94f2-6f8fa4e40981",
# META       "known_warehouses": [
# META         {
# META           "id": "04eb4206-5c5f-46fe-94f2-6f8fa4e40981",
# META           "type": "Lakewarehouse"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# NB_01_Simulateur.ipynb
# Génère le delta transactionnel du jour
# Tourne chaque matin à 7h
# Lit les tables existantes pour garantir la cohérence des IDs

import pandas as pd
import numpy as np
from faker import Faker
from datetime import datetime, date, timedelta
import random
import uuid
import warnings
warnings.filterwarnings('ignore')

fake = Faker('fr_FR')
TODAY = date.today()
NOW = datetime.now()
LAKEHOUSE_PATH = "Files/"

print(f"🚀 Simulateur démarré — {TODAY}")

# ============================================================
# HELPERS
# ============================================================

def gen_id(prefix):
    return f"{prefix}-{uuid.uuid4().hex[:8].upper()}"

def read_table(table_name):
    try:
        return spark.sql(f"SELECT * FROM LH_Immo_Dev.dbo.{table_name}").toPandas()
    except:
        print(f"⚠️  Table {table_name} vide ou inexistante")
        return pd.DataFrame()

def write_excel(df, filename):
    path = f"/lakehouse/default/{LAKEHOUSE_PATH}{filename}.xlsx"
    df.to_excel(path, index=False, sheet_name="Sheet1")
    print(f"✅ {filename}.xlsx écrit ({len(df)} lignes)")

def introduce_anomalies(df, null_rate=0.05, columns_nullable=None):
    df = df.copy()
    if columns_nullable:
        for col in columns_nullable:
            if col in df.columns:
                mask = np.random.random(len(df)) < null_rate
                df.loc[mask, col] = None
    return df

def volume_jour():
    """Saisonnalité réaliste — moins en août, plus en fin d'année"""
    mois = TODAY.month
    jour_semaine = TODAY.weekday()
    
    # Pas de génération le weekend
    if jour_semaine >= 5:
        return None
    
    # Facteur saisonnalité
    facteurs = {1:0.8, 2:0.9, 3:1.0, 4:1.0, 5:1.1, 6:1.0,
                7:0.9, 8:0.5, 9:1.0, 10:1.1, 11:1.2, 12:1.3}
    f = facteurs.get(mois, 1.0)
    
    return {
        "nb_prospects":      int(random.randint(15, 25) * f),
        "nb_investisseurs":  int(random.randint(5, 8) * f),
        "nb_reservations":   int(random.randint(8, 12) * f),
        "nb_ventes":         int(random.randint(3, 5) * f),
        "nb_souscriptions":  int(random.randint(5, 8) * f),
        "nb_crowdfunding":   int(random.randint(2, 4) * f),
        "nb_evenements":     int(random.randint(20, 40) * f),
        "nb_reclamations":   int(random.randint(1, 3) * f),
    }

volumes = volume_jour()
if volumes is None:
    print(f"⏭️  Weekend — pas de génération ({TODAY.strftime('%A')})")
    dbutils.notebook.exit("Weekend")

print(f"📊 Volumes du jour : {volumes}")

# ============================================================
# LECTURE DES RÉFÉRENTIELS
# ============================================================

print("\n📖 Lecture des référentiels...")

df_agences      = read_table("src_agences_regions")
df_conseillers  = read_table("src_conseillers")
df_partenaires  = read_table("src_partenaires_patrimoine")
df_programmes   = read_table("src_programmes_immobiliers")
df_lots         = read_table("src_lots_immobiliers")
df_produits     = read_table("src_produits_investissement")
df_investisseurs = read_table("src_crm_investisseurs")
df_prospects    = read_table("src_crm_prospects")
df_reservations = read_table("src_reservations_immobilieres")
df_ventes       = read_table("src_ventes_immobilieres")

# Lots disponibles
lots_disponibles = df_lots[df_lots["statut_lot"] == "DISPONIBLE"]["lot_id"].tolist() if len(df_lots) > 0 else []
programmes_actifs = df_programmes[df_programmes["statut_programme"] == "EN_COMMERCIALISATION"]["programme_id"].tolist() if len(df_programmes) > 0 else []
conseillers_ids = df_conseillers["conseiller_id"].tolist() if len(df_conseillers) > 0 else []
partenaires_ids = df_partenaires["partenaire_id"].tolist() if len(df_partenaires) > 0 else []
agences_ids = df_agences["agence_id"].tolist() if len(df_agences) > 0 else []
produits_ids = df_produits["produit_id"].tolist() if len(df_produits) > 0 else []
investisseurs_ids = df_investisseurs["investisseur_id"].tolist() if len(df_investisseurs) > 0 else []
reservations_sans_vente = df_reservations[
    ~df_reservations["reservation_id"].isin(df_ventes["reservation_id"].tolist() if len(df_ventes) > 0 else [])
]["reservation_id"].tolist() if len(df_reservations) > 0 else []

print(f"   {len(conseillers_ids)} conseillers | {len(partenaires_ids)} partenaires | {len(lots_disponibles)} lots disponibles")
print(f"   {len(investisseurs_ids)} investisseurs | {len(reservations_sans_vente)} réservations sans vente")

# ============================================================
# 1. PROSPECTS
# ============================================================

print(f"\n👤 Génération de {volumes['nb_prospects']} prospects...")

sources = ["Partenaire", "Web", "Recommandation", "Événement", "Publicité", "Cold Call"]
canaux = ["Digital", "Téléphone", "Physique", "Email", "Réseaux Sociaux"]
statuts_prospect = ["NOUVEAU", "CONTACTE", "QUALIFIE", "EN_COURS", "CHAUD"]
horizons = ["Court terme (< 2 ans)", "Moyen terme (2-5 ans)", "Long terme (> 5 ans)"]
appetences = ["Prudent", "Équilibré", "Dynamique", "Offensif"]

nouveaux_prospects = []
for _ in range(volumes["nb_prospects"]):
    prenom = fake.first_name()
    nom = fake.last_name()
    
    # ~2% de doublons intentionnels
    if investisseurs_ids and random.random() < 0.02:
        email = fake.email()  # email différent mais même personne simulée
    else:
        email = f"{prenom.lower().replace(' ','-')}.{nom.lower().replace(' ','-')}@{random.choice(['gmail.com', 'outlook.fr', 'yahoo.fr', fake.domain_name()])}"

    nouveaux_prospects.append({
        "prospect_id":            gen_id("PROS"),
        "civilite":               random.choice(["M.", "Mme"]),
        "nom":                    nom,
        "prenom":                 prenom,
        "email":                  email,
        "telephone":              fake.phone_number(),
        "date_naissance":         fake.date_of_birth(minimum_age=25, maximum_age=70),
        "ville":                  random.choice(list(df_agences["ville"].unique()) if len(df_agences) > 0 else ["Paris"]),
        "code_postal":            fake.postcode(),
        "pays":                   "France",
        "situation_familiale":    random.choice(["Célibataire", "Marié(e)", "Divorcé(e)", "Pacsé(e)"]),
        "profession":             fake.job(),
        "revenu_annuel_estime":   round(random.uniform(40000, 300000), 2),
        "patrimoine_estime":      round(random.uniform(50000, 2000000), 2),
        "capacite_investissement": round(random.uniform(10000, 500000), 2),
        "objectif_investissement": random.choice(["Défiscalisation", "Revenus Complémentaires", "Retraite", "Transmission"]),
        "horizon_investissement":  random.choice(horizons),
        "appetence_risque":        random.choice(appetences),
        "source_acquisition":      random.choice(sources),
        "campagne_marketing":      f"CAMP-{TODAY.year}-{random.randint(1,10):02d}" if random.random() > 0.3 else None,
        "canal_acquisition":       random.choice(canaux),
        "statut_prospect":         random.choice(statuts_prospect),
        "score_qualification":     random.randint(1, 100),
        "date_creation":           TODAY,
        "created_by":              random.choice(conseillers_ids) if conseillers_ids else None,
        "last_update_date":        TODAY,
        "last_updated_by":         random.choice(conseillers_ids) if conseillers_ids else None,
        "is_deleted":              0,
    })

df_nouveaux_prospects = pd.DataFrame(nouveaux_prospects)
df_nouveaux_prospects = introduce_anomalies(df_nouveaux_prospects, null_rate=0.05,
    columns_nullable=["telephone", "campagne_marketing", "patrimoine_estime"])
write_excel(df_nouveaux_prospects, "src_crm_prospects")

# ============================================================
# 2. INVESTISSEURS
# ============================================================

print(f"\n💼 Génération de {volumes['nb_investisseurs']} investisseurs...")

profils = ["Prudent", "Équilibré", "Dynamique", "Offensif"]
objectifs = ["Défiscalisation", "Revenus Complémentaires", "Retraite", "Transmission", "Plus-Value"]
statuts_kyc = ["EN_COURS", "VALIDE", "REFUSE"]
statuts_lcbft = ["CONFORME", "A_VERIFIER", "BLOQUE"]
statuts_client = ["PROSPECT_CHAUD", "CLIENT_ACTIF", "CLIENT_VIP", "CLIENT_INACTIF"]

nouveaux_investisseurs = []
for _ in range(volumes["nb_investisseurs"]):
    prenom = fake.first_name()
    nom = fake.last_name()
    conseiller_id = random.choice(conseillers_ids) if conseillers_ids else None
    agence_id = df_conseillers[df_conseillers["conseiller_id"] == conseiller_id]["agence_id"].values[0] if conseiller_id and len(df_conseillers) > 0 else random.choice(agences_ids) if agences_ids else None
    partenaire_id = random.choice(partenaires_ids) if partenaires_ids and random.random() > 0.4 else None

    nouveaux_investisseurs.append({
        "investisseur_id":       gen_id("INV"),
        "prospect_id":           gen_id("PROS"),
        "civilite":              random.choice(["M.", "Mme"]),
        "nom":                   nom,
        "prenom":                prenom,
        "email":                 f"{prenom.lower().replace(' ','-')}.{nom.lower().replace(' ','-')}@{random.choice(['gmail.com', 'outlook.fr', fake.domain_name()])}",
        "telephone":             fake.phone_number(),
        "adresse":               fake.street_address(),
        "ville":                 fake.city(),
        "code_postal":           fake.postcode(),
        "pays":                  "France",
        "profession":            fake.job(),
        "situation_familiale":   random.choice(["Célibataire", "Marié(e)", "Divorcé(e)", "Pacsé(e)"]),
        "revenu_annuel":         round(random.uniform(60000, 500000), 2),
        "patrimoine_financier":  round(random.uniform(50000, 3000000), 2),
        "patrimoine_immobilier": round(random.uniform(0, 5000000), 2),
        "profil_investisseur":   random.choice(profils),
        "objectif_principal":    random.choice(objectifs),
        "horizon_placement":     random.choice(horizons),
        "niveau_experience":     random.choice(["Débutant", "Intermédiaire", "Expérimenté"]),
        "statut_kyc":            random.choice(statuts_kyc),
        "statut_lcbft":          random.choice(statuts_lcbft),
        "date_entree_relation":  TODAY,
        "partenaire_id":         partenaire_id,
        "conseiller_id":         conseiller_id,
        "agence_id":             agence_id,
        "statut_client":         random.choice(statuts_client),
        "date_creation":         TODAY,
        "created_by":            conseiller_id,
        "last_update_date":      TODAY,
        "last_updated_by":       conseiller_id,
        "is_deleted":            0,
    })

df_nouveaux_investisseurs = pd.DataFrame(nouveaux_investisseurs)
df_nouveaux_investisseurs = introduce_anomalies(df_nouveaux_investisseurs, null_rate=0.05,
    columns_nullable=["telephone", "partenaire_id", "patrimoine_immobilier"])
write_excel(df_nouveaux_investisseurs, "src_crm_investisseurs")

# ============================================================
# 3. RÉSERVATIONS
# ============================================================

print(f"\n🏠 Génération de {volumes['nb_reservations']} réservations...")

canaux_resa = ["Agence", "Web", "Partenaire", "Téléphone", "Événement"]
modes_financement = ["Crédit", "Comptant", "Mixte"]
statuts_resa = ["CONFIRMEE", "EN_ATTENTE", "ANNULEE"]

reservations = []
lots_reserves_aujourd_hui = []

for _ in range(volumes["nb_reservations"]):
    if not lots_disponibles or not investisseurs_ids:
        break

    lot_id = random.choice(lots_disponibles)
    lots_disponibles.remove(lot_id)
    lots_reserves_aujourd_hui.append(lot_id)

    lot_info = df_lots[df_lots["lot_id"] == lot_id].iloc[0] if len(df_lots) > 0 else None
    programme_id = lot_info["programme_id"] if lot_info is not None else random.choice(programmes_actifs) if programmes_actifs else None
    investisseur_id = random.choice(investisseurs_ids)
    conseiller_id = random.choice(conseillers_ids) if conseillers_ids else None
    partenaire_id = random.choice(partenaires_ids) if partenaires_ids and random.random() > 0.5 else None
    agence_id = df_conseillers[df_conseillers["conseiller_id"] == conseiller_id]["agence_id"].values[0] if conseiller_id and len(df_conseillers) > 0 else random.choice(agences_ids) if agences_ids else None
    prix = float(lot_info["prix_final"]) if lot_info is not None else round(random.uniform(150000, 800000), 2)
    statut = random.choices(statuts_resa, weights=[0.75, 0.20, 0.05])[0]

    reservations.append({
        "reservation_id":              gen_id("RES"),
        "lot_id":                      lot_id,
        "programme_id":                programme_id,
        "investisseur_id":             investisseur_id,
        "partenaire_id":               partenaire_id,
        "conseiller_id":               conseiller_id,
        "agence_id":                   agence_id,
        "date_reservation":            TODAY,
        "montant_reservation":         round(prix * 0.02, 2),
        "prix_reserve":                prix,
        "remise_appliquee":            round(prix * random.uniform(0, 0.03), 2),
        "statut_reservation":          statut,
        "motif_annulation":            fake.sentence() if statut == "ANNULEE" else None,
        "date_annulation":             TODAY if statut == "ANNULEE" else None,
        "date_expiration_reservation": TODAY + timedelta(days=30),
        "canal_reservation":           random.choice(canaux_resa),
        "mode_financement_prevu":      random.choice(modes_financement),
        "apport_prevu":                round(prix * random.uniform(0.1, 0.4), 2),
        "montant_credit_prevu":        round(prix * random.uniform(0.6, 0.9), 2),
        "commentaire_commercial":      fake.sentence() if random.random() > 0.7 else None,
        "created_at":                  NOW,
        "updated_at":                  NOW,
        "is_deleted":                  0,
    })

df_reservations_jour = pd.DataFrame(reservations)
df_reservations_jour = introduce_anomalies(df_reservations_jour, null_rate=0.04,
    columns_nullable=["partenaire_id", "commentaire_commercial", "remise_appliquee"])
write_excel(df_reservations_jour, "src_reservations_immobilieres")

# ============================================================
# 4. VENTES
# ============================================================

print(f"\n💰 Génération de {volumes['nb_ventes']} ventes...")

modes_financement_vente = ["Crédit Immobilier", "Comptant", "Mixte", "Prêt Relais"]
statuts_vente = ["SIGNEE", "EN_COURS", "LIVREE"]
banques = ["BNP Paribas", "Crédit Agricole", "Société Générale", "LCL", "CIC", "Banque Populaire", "Caisse d'Épargne"]

ventes = []
reservations_utilisees = []

resa_disponibles = reservations_sans_vente.copy()
if df_reservations_jour is not None and len(df_reservations_jour) > 0:
    resa_confirmees = df_reservations_jour[df_reservations_jour["statut_reservation"] == "CONFIRMEE"]["reservation_id"].tolist()
    resa_disponibles = resa_confirmees[:volumes["nb_ventes"]]

for reservation_id in resa_disponibles[:volumes["nb_ventes"]]:
    resa_info = None
    if len(df_reservations) > 0:
        resa_match = df_reservations[df_reservations["reservation_id"] == reservation_id]
        if len(resa_match) > 0:
            resa_info = resa_match.iloc[0]

    prix_ttc = float(resa_info["prix_reserve"]) if resa_info is not None else round(random.uniform(150000, 800000), 2)
    mode_financement = random.choice(modes_financement_vente)
    date_signature = TODAY
    date_acte = TODAY + timedelta(days=random.randint(60, 180))
    date_livraison = TODAY + timedelta(days=random.randint(180, 730))

    ventes.append({
        "vente_id":                  gen_id("VENT"),
        "reservation_id":            reservation_id,
        "lot_id":                    resa_info["lot_id"] if resa_info is not None else random.choice(lots_disponibles) if lots_disponibles else gen_id("LOT"),
        "programme_id":              resa_info["programme_id"] if resa_info is not None else random.choice(programmes_actifs) if programmes_actifs else gen_id("PROG"),
        "investisseur_id":           resa_info["investisseur_id"] if resa_info is not None else random.choice(investisseurs_ids) if investisseurs_ids else gen_id("INV"),
        "partenaire_id":             resa_info["partenaire_id"] if resa_info is not None else None,
        "conseiller_id":             resa_info["conseiller_id"] if resa_info is not None else random.choice(conseillers_ids) if conseillers_ids else None,
        "agence_id":                 resa_info["agence_id"] if resa_info is not None else random.choice(agences_ids) if agences_ids else None,
        "date_signature_contrat":    date_signature,
        "date_signature_acte":       date_acte,
        "date_livraison_prevue":     date_livraison,
        "date_livraison_reelle":     None,
        "prix_vente_ht":             round(prix_ttc / 1.2, 2),
        "prix_vente_ttc":            prix_ttc,
        "tva":                       round(prix_ttc - prix_ttc / 1.2, 2),
        "frais_notaire":             round(prix_ttc * random.uniform(0.02, 0.04), 2),
        "montant_total_operation":   round(prix_ttc * 1.03, 2),
        "montant_apport":            round(prix_ttc * random.uniform(0.1, 0.4), 2),
        "montant_credit":            round(prix_ttc * random.uniform(0.6, 0.9), 2),
        "mode_financement":          mode_financement,
        "banque_financement":        random.choice(banques) if mode_financement != "Comptant" else None,
        "statut_vente":              random.choices(statuts_vente, weights=[0.7, 0.25, 0.05])[0],
        "motif_echec":               None,
        "created_at":                NOW,
        "updated_at":                NOW,
        "is_deleted":                0,
    })

df_ventes_jour = pd.DataFrame(ventes)
write_excel(df_ventes_jour, "src_ventes_immobilieres")

# ============================================================
# 5. COMMISSIONS
# ============================================================

print(f"\n💸 Génération des commissions...")

types_operations = ["VENTE_IMMOBILIER", "SOUSCRIPTION_SCPI", "CROWDFUNDING"]
statuts_commission = ["EN_ATTENTE", "VALIDEE", "PAYEE", "BLOQUEE"]
modes_paiement = ["Virement", "Chèque", "Prélèvement"]

commissions = []

# Commissions sur les ventes du jour
for _, vente in df_ventes_jour.iterrows():
    taux = round(random.uniform(0.02, 0.05), 4)
    montant_brut = round(float(vente["prix_vente_ttc"]) * taux, 2)
    montant_net = round(montant_brut * 0.85, 2)
    part_partenaire = round(montant_brut * 0.4, 2) if vente["partenaire_id"] else 0
    part_interne = round(montant_brut - part_partenaire, 2)
    statut = random.choices(statuts_commission, weights=[0.4, 0.35, 0.2, 0.05])[0]

    commissions.append({
        "commission_id":              gen_id("COM"),
        "type_operation":             "VENTE_IMMOBILIER",
        "operation_id":               vente["vente_id"],
        "vente_id":                   vente["vente_id"],
        "souscription_id":            None,
        "operation_crowdfunding_id":  None,
        "investisseur_id":            vente["investisseur_id"],
        "partenaire_id":              vente["partenaire_id"],
        "conseiller_id":              vente["conseiller_id"],
        "agence_id":                  vente["agence_id"],
        "produit_id":                 None,
        "programme_id":               vente["programme_id"],
        "montant_operation":          vente["prix_vente_ttc"],
        "taux_commission":            taux,
        "montant_commission_brut":    montant_brut,
        "montant_commission_net":     montant_net,
        "part_commission_partenaire": part_partenaire,
        "part_commission_interne":    part_interne,
        "statut_commission":          statut,
        "date_calcul":                TODAY,
        "date_validation":            TODAY + timedelta(days=random.randint(1, 15)) if statut in ["VALIDEE", "PAYEE"] else None,
        "date_paiement":              TODAY + timedelta(days=random.randint(15, 45)) if statut == "PAYEE" else None,
        "mode_paiement":              random.choice(modes_paiement),
        "motif_blocage":              fake.sentence() if statut == "BLOQUEE" else None,
        "created_at":                 NOW,
        "updated_at":                 NOW,
        "is_deleted":                 0,
    })

df_commissions_jour = pd.DataFrame(commissions)
df_commissions_jour = introduce_anomalies(df_commissions_jour, null_rate=0.03,
    columns_nullable=["motif_blocage", "date_paiement"])
write_excel(df_commissions_jour, "src_commissions")

# ============================================================
# 6. SOUSCRIPTIONS PIERRE-PAPIER
# ============================================================

print(f"\n📋 Génération de {volumes['nb_souscriptions']} souscriptions pierre-papier...")

types_supports = ["SCPI", "OPCI", "SCI", "FCPI"]
statuts_sous = ["EN_ATTENTE", "VALIDEE", "REJETEE"]
modes_paiement_sous = ["Virement", "Prélèvement", "Chèque"]

souscriptions = []
for _ in range(volumes["nb_souscriptions"]):
    if not investisseurs_ids or not produits_ids:
        break

    investisseur_id = random.choice(investisseurs_ids)
    produit_id = random.choice(produits_ids)
    conseiller_id = random.choice(conseillers_ids) if conseillers_ids else None
    partenaire_id = random.choice(partenaires_ids) if partenaires_ids and random.random() > 0.5 else None
    agence_id = df_conseillers[df_conseillers["conseiller_id"] == conseiller_id]["agence_id"].values[0] if conseiller_id and len(df_conseillers) > 0 else random.choice(agences_ids) if agences_ids else None
    montant = round(random.uniform(5000, 200000), 2)
    prix_part = round(random.uniform(100, 1000), 2)
    nb_parts = round(montant / prix_part, 4)
    statut = random.choices(statuts_sous, weights=[0.3, 0.6, 0.1])[0]

    souscriptions.append({
        "souscription_id":       gen_id("SOUS"),
        "investisseur_id":       investisseur_id,
        "partenaire_id":         partenaire_id,
        "conseiller_id":         conseiller_id,
        "agence_id":             agence_id,
        "produit_id":            produit_id,
        "societe_gestion_id":    gen_id("SOC"),
        "type_support":          random.choice(types_supports),
        "nom_support":           f"Support {fake.last_name()}",
        "date_souscription":     TODAY,
        "montant_souscrit":      montant,
        "nombre_parts":          nb_parts,
        "prix_part":             prix_part,
        "frais_souscription":    round(montant * random.uniform(0.01, 0.04), 2),
        "duree_recommandee":     f"{random.randint(5, 20)} ans",
        "rendement_previsionnel": round(random.uniform(0.03, 0.08), 4),
        "statut_souscription":   statut,
        "date_validation":       TODAY + timedelta(days=random.randint(1, 10)) if statut == "VALIDEE" else None,
        "date_rejet":            TODAY if statut == "REJETEE" else None,
        "motif_rejet":           fake.sentence() if statut == "REJETEE" else None,
        "mode_paiement":         random.choice(modes_paiement_sous),
        "created_at":            NOW,
        "updated_at":            NOW,
        "is_deleted":            0,
    })

df_souscriptions_jour = pd.DataFrame(souscriptions)
df_souscriptions_jour = introduce_anomalies(df_souscriptions_jour, null_rate=0.04,
    columns_nullable=["partenaire_id", "motif_rejet"])
write_excel(df_souscriptions_jour, "src_souscriptions_pierre_papier")

# ============================================================
# 7. CROWDFUNDING
# ============================================================

print(f"\n🌐 Génération de {volumes['nb_crowdfunding']} opérations crowdfunding...")

statuts_crowd = ["EN_COURS", "REMBOURSE", "EN_RETARD", "DEFAUT"]
fiscalites = ["Flat Tax", "IR", "Exonéré"]

crowdfunding = []
for _ in range(volumes["nb_crowdfunding"]):
    if not investisseurs_ids:
        break

    investisseur_id = random.choice(investisseurs_ids)
    conseiller_id = random.choice(conseillers_ids) if conseillers_ids else None
    partenaire_id = random.choice(partenaires_ids) if partenaires_ids and random.random() > 0.5 else None
    agence_id = df_conseillers[df_conseillers["conseiller_id"] == conseiller_id]["agence_id"].values[0] if conseiller_id and len(df_conseillers) > 0 else random.choice(agences_ids) if agences_ids else None
    montant = round(random.uniform(1000, 50000), 2)
    taux = round(random.uniform(0.06, 0.12), 4)
    duree = random.choice([12, 18, 24, 36])
    statut = random.choices(statuts_crowd, weights=[0.5, 0.35, 0.10, 0.05])[0]
    date_remboursement_prevue = TODAY + timedelta(days=duree*30)

    crowdfunding.append({
        "operation_crowdfunding_id":  gen_id("CROW"),
        "investisseur_id":            investisseur_id,
        "partenaire_id":              partenaire_id,
        "conseiller_id":              conseiller_id,
        "agence_id":                  agence_id,
        "projet_id":                  gen_id("PROJ"),
        "nom_projet":                 f"Projet {fake.city()} {random.randint(2023,2026)}",
        "promoteur_id":               gen_id("PROM"),
        "ville":                      random.choice(list(VILLES.keys())),
        "region":                     fake.region(),
        "date_investissement":        TODAY,
        "montant_investi":            montant,
        "taux_rendement_annuel_prevu": taux,
        "duree_mois":                 duree,
        "statut_operation":           statut,
        "date_remboursement_prevue":  date_remboursement_prevue,
        "date_remboursement_reelle":  TODAY + timedelta(days=duree*30 + random.randint(-10, 30)) if statut == "REMBOURSE" else None,
        "montant_rembourse":          round(montant * (1 + taux * duree/12), 2) if statut == "REMBOURSE" else None,
        "interets_bruts":             round(montant * taux * duree/12, 2) if statut == "REMBOURSE" else None,
        "fiscalite_appliquee":        random.choice(fiscalites),
        "incident_paiement":          1 if statut in ["EN_RETARD", "DEFAUT"] else 0,
        "created_at":                 NOW,
        "updated_at":                 NOW,
        "is_deleted":                 0,
    })

df_crowdfunding_jour = pd.DataFrame(crowdfunding)
write_excel(df_crowdfunding_jour, "src_operations_crowdfunding")

# ============================================================
# 8. ÉVÉNEMENTS CLIENTS
# ============================================================

print(f"\n📅 Génération de {volumes['nb_evenements']} événements clients...")

types_evt = ["Appel Entrant", "Appel Sortant", "Email", "RDV Physique", "Visioconférence", "SMS"]
canaux_evt = ["Téléphone", "Email", "Physique", "Digital", "Courrier"]
statuts_evt = ["REALISE", "PLANIFIE", "ANNULE"]
resultats = ["Intéressé", "Pas Intéressé", "À Rappeler", "Dossier Ouvert", "RDV Pris"]
priorites = ["HAUTE", "NORMALE", "BASSE"]

evenements = []
all_contacts = investisseurs_ids.copy()
if len(df_prospects) > 0:
    all_contacts += df_prospects["prospect_id"].tolist()

for _ in range(volumes["nb_evenements"]):
    if not all_contacts or not conseillers_ids:
        break

    contact_id = random.choice(all_contacts)
    is_investisseur = contact_id in investisseurs_ids

    evenements.append({
        "evenement_id":          gen_id("EVT"),
        "investisseur_id":       contact_id if is_investisseur else None,
        "prospect_id":           None if is_investisseur else contact_id,
        "partenaire_id":         random.choice(partenaires_ids) if partenaires_ids and random.random() > 0.7 else None,
        "conseiller_id":         random.choice(conseillers_ids),
        "type_evenement":        random.choice(types_evt),
        "canal_evenement":       random.choice(canaux_evt),
        "objet_evenement":       fake.sentence(),
        "date_evenement":        TODAY,
        "statut_evenement":      random.choices(statuts_evt, weights=[0.7, 0.25, 0.05])[0],
        "resultat_evenement":    random.choice(resultats),
        "prochaine_action":      fake.sentence() if random.random() > 0.5 else None,
        "date_prochaine_action": TODAY + timedelta(days=random.randint(1, 30)) if random.random() > 0.5 else None,
        "priorite":              random.choice(priorites),
        "commentaire":           fake.paragraph() if random.random() > 0.6 else None,
        "created_at":            NOW,
        "created_by":            random.choice(conseillers_ids),
        "updated_at":            NOW,
        "is_deleted":            0,
    })

df_evenements_jour = pd.DataFrame(evenements)
df_evenements_jour = introduce_anomalies(df_evenements_jour, null_rate=0.05,
    columns_nullable=["commentaire", "prochaine_action", "partenaire_id"])
write_excel(df_evenements_jour, "src_evenements_clients")

# ============================================================
# 9. RÉCLAMATIONS
# ============================================================

print(f"\n⚠️  Génération de {volumes['nb_reclamations']} réclamations...")

types_recla = ["Délai", "Qualité", "Commercial", "Administratif", "Financier"]
categories = ["Mineure", "Majeure", "Critique"]
niveaux_urgence = ["FAIBLE", "MOYEN", "ELEVE", "CRITIQUE"]
statuts_recla = ["OUVERTE", "EN_COURS", "RESOLUE", "CLOTUREE"]

reclamations = []
for _ in range(volumes["nb_reclamations"]):
    if not investisseurs_ids:
        break

    statut = random.choices(statuts_recla, weights=[0.3, 0.4, 0.2, 0.1])[0]

    reclamations.append({
        "reclamation_id":           gen_id("RECLA"),
        "investisseur_id":          random.choice(investisseurs_ids),
        "partenaire_id":            random.choice(partenaires_ids) if partenaires_ids and random.random() > 0.6 else None,
        "operation_id":             gen_id("VENT"),
        "type_operation":           "VENTE_IMMOBILIER",
        "type_reclamation":         random.choice(types_recla),
        "categorie_reclamation":    random.choice(categories),
        "niveau_urgence":           random.choice(niveaux_urgence),
        "statut_reclamation":       statut,
        "date_ouverture":           TODAY,
        "date_resolution":          TODAY + timedelta(days=random.randint(1, 30)) if statut in ["RESOLUE", "CLOTUREE"] else None,
        "delai_resolution_jours":   random.randint(1, 30) if statut in ["RESOLUE", "CLOTUREE"] else None,
        "responsable_traitement_id": random.choice(conseillers_ids) if conseillers_ids else None,
        "motif_reclamation":        fake.sentence(),
        "resolution_apportee":      fake.sentence() if statut in ["RESOLUE", "CLOTUREE"] else None,
        "impact_financier_estime":  round(random.uniform(0, 50000), 2) if random.random() > 0.5 else None,
        "created_at":               NOW,
        "updated_at":               NOW,
        "is_deleted":               0,
    })

df_reclamations_jour = pd.DataFrame(reclamations)
write_excel(df_reclamations_jour, "src_reclamations_incidents")

# ============================================================
# RÉSUMÉ
# ============================================================

print(f"""
{'='*60}
✅ Simulation du {TODAY} terminée

📊 Généré aujourd'hui :
   👤 Prospects        : {len(df_nouveaux_prospects)}
   💼 Investisseurs    : {len(df_nouveaux_investisseurs)}
   🏠 Réservations     : {len(df_reservations_jour)}
   💰 Ventes           : {len(df_ventes_jour)}
   💸 Commissions      : {len(df_commissions_jour)}
   📋 Souscriptions    : {len(df_souscriptions_jour)}
   🌐 Crowdfunding     : {len(df_crowdfunding_jour)}
   📅 Événements       : {len(df_evenements_jour)}
   ⚠️  Réclamations    : {len(df_reclamations_jour)}

📁 Fichiers écrits dans : {LAKEHOUSE_PATH}
🔄 PL_Master s'exécutera à 8h
{'='*60}
""")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
