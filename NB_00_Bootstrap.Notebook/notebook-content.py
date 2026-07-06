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

# NB_00_Bootstrap.ipynb
# Génère tous les référentiels une seule fois
# Idempotent - vérifie les tables existantes avant de générer

import pandas as pd
import numpy as np
from faker import Faker
from datetime import datetime, date, timedelta
import random
import uuid
import warnings
warnings.filterwarnings('ignore')

fake = Faker('fr_FR')
Faker.seed(42)
random.seed(42)
np.random.seed(42)

TODAY = date.today()
LAKEHOUSE_PATH = "Files/"

# ============================================================
# HELPERS
# ============================================================

def gen_id(prefix):
    return f"{prefix}-{uuid.uuid4().hex[:8].upper()}"

def table_exists(table_name):
    try:
        df = spark.sql(f"SELECT 1 FROM LH_Immo_Dev.dbo.{table_name} LIMIT 1")
        return df.count() > 0
    except:
        return False

def write_excel(df, filename):
    path = f"/lakehouse/default/{LAKEHOUSE_PATH}{filename}.xlsx"
    df.to_excel(path, index=False, sheet_name="Sheet1")
    print(f"✅ {filename}.xlsx écrit ({len(df)} lignes)")

def introduce_anomalies(df, null_rate=0.05, columns_nullable=None):
    """Introduit des anomalies réalistes dans le dataframe"""
    df = df.copy()
    if columns_nullable:
        for col in columns_nullable:
            if col in df.columns:
                mask = np.random.random(len(df)) < null_rate
                df.loc[mask, col] = None
    return df

# ============================================================
# PARAMÈTRES
# ============================================================

VILLES = {
    "Paris":       {"region_id": "REG-IDF", "nom_region": "Île-de-France",        "nb_agences": 4, "nb_conseillers": 400},
    "Lyon":        {"region_id": "REG-ARA", "nom_region": "Auvergne-Rhône-Alpes", "nb_agences": 2, "nb_conseillers": 200},
    "Marseille":   {"region_id": "REG-PAC", "nom_region": "PACA",                 "nb_agences": 2, "nb_conseillers": 200},
    "Toulouse":    {"region_id": "REG-OCC", "nom_region": "Occitanie",            "nb_agences": 1, "nb_conseillers": 150},
    "Bordeaux":    {"region_id": "REG-NAQ", "nom_region": "Nouvelle-Aquitaine",   "nb_agences": 1, "nb_conseillers": 150},
    "Nice":        {"region_id": "REG-PAC", "nom_region": "PACA",                 "nb_agences": 1, "nb_conseillers": 150},
    "Strasbourg":  {"region_id": "REG-GRE", "nom_region": "Grand Est",            "nb_agences": 1, "nb_conseillers": 150},
}

NB_PROGRAMMES   = 50
NB_PARTENAIRES  = 80
NB_PRODUITS     = 30
NB_LOTS_PAR_PROG = 20

# ============================================================
# 1. AGENCES & RÉGIONS
# ============================================================

if table_exists("src_agences_regions"):
    print("⏭️  src_agences_regions existe déjà — skip")
else:
    agences = []
    directeurs_region = {}

    for ville, config in VILLES.items():
        region_id = config["region_id"]
        if region_id not in directeurs_region:
            directeurs_region[region_id] = gen_id("CONS")

        for i in range(config["nb_agences"]):
            agence_id = gen_id("AGE")
            agences.append({
                "agence_id":            agence_id,
                "nom_agence":           f"Immo Invest {ville} {i+1}",
                "code_agence":          f"AG-{ville[:3].upper()}-{i+1:02d}",
                "region_id":            region_id,
                "nom_region":           config["nom_region"],
                "directeur_region_id":  directeurs_region[region_id],
                "responsable_agence_id": gen_id("CONS"),
                "ville":                ville,
                "code_postal":          fake.postcode(),
                "adresse":              fake.street_address(),
                "pays":                 "France",
                "zone_commerciale":     f"Zone {ville}",
                "statut_agence":        "ACTIVE",
                "date_ouverture":       fake.date_between(start_date=date(2015,1,1), end_date=date(2020,12,31)),
                "date_fermeture":       None,
                "created_at":           datetime(2015, 1, 1),
                "updated_at":           datetime(2015, 1, 1),
                "is_active":            1,
            })

    df_agences = pd.DataFrame(agences)
    write_excel(df_agences, "src_agences_regions")
    print(f"   → {len(df_agences)} agences générées")

# ============================================================
# 2. CONSEILLERS
# ============================================================

if table_exists("src_conseillers"):
    print("⏭️  src_conseillers existe déjà — skip")
else:
    df_agences_ref = pd.read_excel(f"/lakehouse/default/{LAKEHOUSE_PATH}src_agences_regions.xlsx")
    
    conseillers = []
    postes = ["Conseiller Patrimonial", "Conseiller Senior", "Manager Équipe", 
              "Directeur Agence", "Conseiller Junior", "Chargé ADV"]
    specialites = ["Immobilier Neuf", "Pierre-Papier", "Crowdfunding", "Mixte"]
    
    matricule_counter = 1000
    
    for _, agence in df_agences_ref.iterrows():
        ville = agence["ville"]
        nb_conseillers = VILLES[ville]["nb_conseillers"] // VILLES[ville]["nb_agences"]
        
        for i in range(nb_conseillers):
            prenom = fake.first_name()
            nom = fake.last_name()
            email = f"{prenom.lower().replace(' ','-')}.{nom.lower().replace(' ','-')}@immo-invest.fr"
            poste = random.choice(postes)
            objectif_annuel = round(random.uniform(800000, 3000000), 2)
            
            conseillers.append({
                "conseiller_id":         gen_id("CONS"),
                "matricule":             f"MAT-{matricule_counter}",
                "nom":                   nom,
                "prenom":                prenom,
                "email":                 email,
                "telephone":             fake.phone_number(),
                "poste":                 poste,
                "agence_id":             agence["agence_id"],
                "region_id":             agence["region_id"],
                "manager_id":            None,
                "date_arrivee":          fake.date_between(start_date=date(2015,1,1), end_date=date(2023,12,31)),
                "date_depart":           None,
                "statut_collaborateur":  "ACTIF",
                "specialite_produit":    random.choice(specialites),
                "objectif_annuel":       objectif_annuel,
                "objectif_mensuel_moyen": round(objectif_annuel / 12, 2),
                "created_at":            datetime(2015, 1, 1),
                "updated_at":            datetime(2015, 1, 1),
                "is_active":             1,
            })
            matricule_counter += 1

    df_conseillers = pd.DataFrame(conseillers)
    df_conseillers = introduce_anomalies(df_conseillers, null_rate=0.03, 
                                          columns_nullable=["manager_id", "date_depart", "telephone"])
    write_excel(df_conseillers, "src_conseillers")
    print(f"   → {len(df_conseillers)} conseillers générés")

# ============================================================
# 3. PARTENAIRES
# ============================================================

if table_exists("src_partenaires_patrimoine"):
    print("⏭️  src_partenaires_patrimoine existe déjà — skip")
else:
    types_partenaires = ["CGP", "Notaire", "Banque", "Courtier", "Agent Immobilier", "Family Office"]
    niveaux = ["Gold", "Silver", "Bronze"]
    segments = ["Premium", "Standard", "Strategic"]

    partenaires = []
    for _ in range(NB_PARTENAIRES):
        type_p = random.choice(types_partenaires)
        raison_sociale = f"{fake.company()} {type_p}"
        nom_contact = fake.last_name()
        prenom_contact = fake.first_name()

        partenaires.append({
            "partenaire_id":            gen_id("PAR"),
            "raison_sociale":           raison_sociale,
            "siret":                    fake.siret(),
            "type_partenaire":          type_p,
            "statut_partenaire":        "ACTIF",
            "nom_contact_principal":    nom_contact,
            "prenom_contact_principal": prenom_contact,
            "email_contact":            f"{prenom_contact.lower()}.{nom_contact.lower()}@{fake.domain_name()}",
            "telephone_contact":        fake.phone_number(),
            "adresse":                  fake.street_address(),
            "ville":                    random.choice(list(VILLES.keys())),
            "code_postal":              fake.postcode(),
            "region":                   fake.region(),
            "pays":                     "France",
            "date_signature_convention": fake.date_between(start_date=date(2018,1,1), end_date=date(2023,12,31)),
            "niveau_partenaire":        random.choice(niveaux),
            "segment_partenaire":       random.choice(segments),
            "nombre_clients_actifs":    random.randint(5, 150),
            "encours_total_apporte":    round(random.uniform(500000, 50000000), 2),
            "commission_rate_default":  round(random.uniform(0.005, 0.025), 4),
            "manager_interne_id":       gen_id("CONS"),
            "conseiller_referent_id":   gen_id("CONS"),
            "statut_convention":        "ACTIVE",
            "date_derniere_activite":   fake.date_between(start_date=date(2024,1,1), end_date=TODAY),
            "created_at":               datetime(2018, 1, 1),
            "updated_at":               datetime(2018, 1, 1),
            "is_active":                1,
        })

    df_partenaires = pd.DataFrame(partenaires)
    df_partenaires = introduce_anomalies(df_partenaires, null_rate=0.04,
                                          columns_nullable=["siret", "telephone_contact", "date_derniere_activite"])
    write_excel(df_partenaires, "src_partenaires_patrimoine")
    print(f"   → {len(df_partenaires)} partenaires générés")

# ============================================================
# 4. PROGRAMMES IMMOBILIERS
# ============================================================

if table_exists("src_programmes_immobiliers"):
    print("⏭️  src_programmes_immobiliers existe déjà — skip")
else:
    types_programmes = ["Résidentiel", "Commercial", "Mixte"]
    types_actifs = ["Appartement", "Bureau", "Commerce", "Résidence Services"]
    segments = ["Premium", "Standard", "Accessible"]
    dispositifs = ["Pinel", "LMNP", "Malraux", "Déficit Foncier", "Nue-Propriété"]
    labels = ["BBC", "HQE", "RT2012", "RE2020", "BBC Rénovation"]
    statuts = ["EN_COMMERCIALISATION", "LIVRE", "EN_CONSTRUCTION", "TERMINE"]

    programmes = []
    for i in range(NB_PROGRAMMES):
        ville = random.choice(list(VILLES.keys()))
        nb_lots = random.randint(10, 60)
        nb_disponibles = random.randint(0, nb_lots)
        date_lancement = fake.date_between(start_date=date(2020,1,1), end_date=date(2024,12,31))
        date_livraison_prevue = date_lancement + timedelta(days=random.randint(365, 1095))

        programmes.append({
            "programme_id":              gen_id("PROG"),
            "nom_programme":             f"Résidence {fake.last_name()} - {ville}",
            "type_programme":            random.choice(types_programmes),
            "promoteur_id":              gen_id("PROM"),
            "ville":                     ville,
            "code_postal":               fake.postcode(),
            "region":                    VILLES[ville]["nom_region"],
            "adresse":                   fake.street_address(),
            "latitude":                  round(float(fake.latitude()), 6),
            "longitude":                 round(float(fake.longitude()), 6),
            "type_actif":                random.choice(types_actifs),
            "segment_marche":            random.choice(segments),
            "statut_programme":          random.choice(statuts),
            "date_lancement_commercial": date_lancement,
            "date_livraison_prevue":     date_livraison_prevue,
            "date_livraison_reelle":     date_livraison_prevue + timedelta(days=random.randint(-30, 180)) if random.random() > 0.4 else None,
            "nombre_lots_total":         nb_lots,
            "nombre_lots_disponibles":   nb_disponibles,
            "prix_moyen_m2":             round(random.uniform(3500, 12000), 2),
            "rentabilite_cible":         round(random.uniform(0.03, 0.07), 4),
            "zone_fiscale":              random.choice(["A", "A bis", "B1", "B2"]),
            "dispositif_fiscal":         random.choice(dispositifs),
            "label_energetique":         random.choice(labels),
            "note_programme":            round(random.uniform(3.0, 5.0), 2),
            "created_at":                datetime(2020, 1, 1),
            "updated_at":                datetime(2020, 1, 1),
            "is_active":                 1,
        })

    df_programmes = pd.DataFrame(programmes)
    write_excel(df_programmes, "src_programmes_immobiliers")
    print(f"   → {len(df_programmes)} programmes générés")

# ============================================================
# 5. LOTS IMMOBILIERS
# ============================================================

if table_exists("src_lots_immobiliers"):
    print("⏭️  src_lots_immobiliers existe déjà — skip")
else:
    df_prog_ref = pd.read_excel(f"/lakehouse/default/{LAKEHOUSE_PATH}src_programmes_immobiliers.xlsx")
    
    typologies = ["T1", "T2", "T3", "T4", "T5"]
    types_lots = ["Appartement", "Studio", "Duplex", "Penthouse"]
    orientations = ["Nord", "Sud", "Est", "Ouest", "Nord-Est", "Sud-Ouest"]
    statuts_lot = ["DISPONIBLE", "RESERVE", "VENDU", "INDISPONIBLE"]

    lots = []
    for _, prog in df_prog_ref.iterrows():
        nb_lots = prog["nombre_lots_total"]
        for j in range(nb_lots):
            surface = round(random.uniform(25, 120), 2)
            prix_cat = round(surface * float(prog["prix_moyen_m2"]) * random.uniform(0.9, 1.1), 2)
            loyer = round(surface * random.uniform(12, 25), 2)

            lots.append({
                "lot_id":                    gen_id("LOT"),
                "programme_id":              prog["programme_id"],
                "numero_lot":                f"LOT-{j+1:03d}",
                "type_lot":                  random.choice(types_lots),
                "typologie":                 random.choice(typologies),
                "surface_m2":                surface,
                "etage":                     random.randint(0, 10),
                "orientation":               random.choice(orientations),
                "parking_inclus":            random.choice([0, 1]),
                "prix_catalogue":            prix_cat,
                "prix_remise":               round(prix_cat * random.uniform(0.95, 1.0), 2),
                "prix_final":                round(prix_cat * random.uniform(0.93, 0.99), 2),
                "loyer_estime_mensuel":       loyer,
                "rentabilite_brute_estimee": round(loyer * 12 / prix_cat, 4),
                "statut_lot":                "DISPONIBLE",
                "date_disponibilite":        prog["date_lancement_commercial"],
                "date_reservation":          None,
                "date_vente":                None,
                "investisseur_id":           None,
                "partenaire_id":             None,
                "created_at":               datetime(2020, 1, 1),
                "updated_at":               datetime(2020, 1, 1),
                "is_active":                1,
            })

    df_lots = pd.DataFrame(lots)
    write_excel(df_lots, "src_lots_immobiliers")
    print(f"   → {len(df_lots)} lots générés")

# ============================================================
# 6. PRODUITS INVESTISSEMENT
# ============================================================

if table_exists("src_produits_investissement"):
    print("⏭️  src_produits_investissement existe déjà — skip")
else:
    familles = ["SCPI", "OPCI", "SCI", "FCPI", "FIP"]
    fiscalites = ["IR", "IS", "Assurance-Vie", "PEA", "Compte-Titres"]
    risques = ["Faible", "Modéré", "Élevé"]
    statuts_prod = ["EN_COMMERCIALISATION", "FERME", "SUSPENDU"]

    produits = []
    for i in range(NB_PRODUITS):
        famille = random.choice(familles)
        rendement = round(random.uniform(0.03, 0.08), 4)

        produits.append({
            "produit_id":                       gen_id("PROD"),
            "nom_produit":                      f"{famille} {fake.last_name()} Patrimoine {i+1}",
            "famille_produit":                  famille,
            "type_produit":                     famille,
            "sous_type_produit":                f"{famille} Diversifié",
            "fiscalite":                        random.choice(fiscalites),
            "niveau_risque":                    random.choice(risques),
            "duree_recommandee":                f"{random.randint(5, 20)} ans",
            "rendement_cible_annuel":           rendement,
            "montant_minimum_investissement":   round(random.choice([1000, 5000, 10000, 50000]), 2),
            "frais_entree":                     round(random.uniform(0.01, 0.05), 4),
            "frais_gestion_annuels":            round(random.uniform(0.005, 0.02), 4),
            "frais_sortie":                     round(random.uniform(0.0, 0.02), 4),
            "societe_gestion_id":               gen_id("SOC"),
            "promoteur_id":                     gen_id("PROM"),
            "statut_commercialisation":         random.choice(statuts_prod),
            "date_debut_commercialisation":     fake.date_between(start_date=date(2018,1,1), end_date=date(2022,12,31)),
            "date_fin_commercialisation":       None,
            "created_at":                       datetime(2018, 1, 1),
            "updated_at":                       datetime(2018, 1, 1),
            "is_active":                        1,
        })

    df_produits = pd.DataFrame(produits)
    write_excel(df_produits, "src_produits_investissement")
    print(f"   → {len(df_produits)} produits générés")

# ============================================================
# 7. OBJECTIFS COMMERCIAUX
# ============================================================

if table_exists("src_objectifs_commerciaux"):
    print("⏭️  src_objectifs_commerciaux existe déjà — skip")
else:
    df_agences_ref = pd.read_excel(f"/lakehouse/default/{LAKEHOUSE_PATH}src_agences_regions.xlsx")
    df_conseillers_ref = pd.read_excel(f"/lakehouse/default/{LAKEHOUSE_PATH}src_conseillers.xlsx")

    objectifs = []
    annees = [2023, 2024, 2025, 2026]
    familles_prod = ["Immobilier Neuf", "Pierre-Papier", "Crowdfunding"]
    niveaux = ["CONSEILLER", "AGENCE", "REGION"]

    for annee in annees:
        for mois in range(1, 13):
            if date(annee, mois, 1) > TODAY:
                continue

            # Objectifs par agence
            for _, agence in df_agences_ref.iterrows():
                for famille in familles_prod:
                    objectifs.append({
                        "objectif_id":                    gen_id("OBJ"),
                        "annee":                          annee,
                        "mois":                           mois,
                        "periode":                        f"{annee}-{mois:02d}",
                        "niveau_objectif":                "AGENCE",
                        "region_id":                      agence["region_id"],
                        "agence_id":                      agence["agence_id"],
                        "conseiller_id":                  None,
                        "partenaire_id":                  None,
                        "famille_produit":                famille,
                        "type_produit":                   famille,
                        "objectif_ca":                    round(random.uniform(200000, 2000000), 2),
                        "objectif_nombre_ventes":         random.randint(2, 20),
                        "objectif_nombre_reservations":   random.randint(5, 30),
                        "objectif_montant_souscriptions": round(random.uniform(100000, 1000000), 2),
                        "objectif_commissions":           round(random.uniform(10000, 100000), 2),
                        "objectif_nouveaux_clients":      random.randint(3, 25),
                        "created_at":                     datetime(annee, mois, 1),
                        "updated_at":                     datetime(annee, mois, 1),
                        "is_active":                      1,
                    })

    df_objectifs = pd.DataFrame(objectifs)
    write_excel(df_objectifs, "src_objectifs_commerciaux")
    print(f"   → {len(df_objectifs)} objectifs générés")

# ============================================================
# 8. SECURITY USER ACCESS
# ============================================================

if table_exists("src_security_user_access"):
    print("⏭️  src_security_user_access existe déjà — skip")
else:
    df_agences_ref = pd.read_excel(f"/lakehouse/default/{LAKEHOUSE_PATH}src_agences_regions.xlsx")
    df_conseillers_ref = pd.read_excel(f"/lakehouse/default/{LAKEHOUSE_PATH}src_conseillers.xlsx")

    acces = []

    # Direction
    acces.append({
        "user_access_id":       gen_id("ACC"),
        "user_email":           "direction@immo-invest.fr",
        "user_name":            "Direction Générale",
        "role_metier":          "DIRECTION",
        "access_level":         "FULL",
        "region_id":            None,
        "agence_id":            None,
        "conseiller_id":        None,
        "partenaire_id":        None,
        "can_view_commissions": 1,
        "can_view_margin":      1,
        "can_view_personal_data": 1,
        "can_export_data":      1,
        "start_date":           date(2020, 1, 1),
        "end_date":             None,
        "is_active":            1,
        "created_at":           datetime(2020, 1, 1),
        "updated_at":           datetime(2020, 1, 1),
    })

    # Un accès par région
    for region_id in df_agences_ref["region_id"].unique():
        acces.append({
            "user_access_id":       gen_id("ACC"),
            "user_email":           f"dr.{region_id.lower().replace('-','.')}@immo-invest.fr",
            "user_name":            f"Directeur {region_id}",
            "role_metier":          "REGION",
            "access_level":         "REGION",
            "region_id":            region_id,
            "agence_id":            None,
            "conseiller_id":        None,
            "partenaire_id":        None,
            "can_view_commissions": 1,
            "can_view_margin":      1,
            "can_view_personal_data": 0,
            "can_export_data":      1,
            "start_date":           date(2020, 1, 1),
            "end_date":             None,
            "is_active":            1,
            "created_at":           datetime(2020, 1, 1),
            "updated_at":           datetime(2020, 1, 1),
        })

    # Un accès par agence
    for _, agence in df_agences_ref.iterrows():
        acces.append({
            "user_access_id":       gen_id("ACC"),
            "user_email":           f"da.{agence['code_agence'].lower().replace('-','.')}@immo-invest.fr",
            "user_name":            f"Directeur {agence['nom_agence']}",
            "role_metier":          "AGENCE",
            "access_level":         "AGENCE",
            "region_id":            agence["region_id"],
            "agence_id":            agence["agence_id"],
            "conseiller_id":        None,
            "partenaire_id":        None,
            "can_view_commissions": 1,
            "can_view_margin":      0,
            "can_view_personal_data": 1,
            "can_export_data":      0,
            "start_date":           date(2020, 1, 1),
            "end_date":             None,
            "is_active":            1,
            "created_at":           datetime(2020, 1, 1),
            "updated_at":           datetime(2020, 1, 1),
        })

    df_acces = pd.DataFrame(acces)
    write_excel(df_acces, "src_security_user_access")
    print(f"   → {len(df_acces)} accès générés")

print("\n🎉 Bootstrap terminé — tous les référentiels sont prêts")
print(f"   Date : {TODAY}")
print(f"   Fichiers écrits dans : {LAKEHOUSE_PATH}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
