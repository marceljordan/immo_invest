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
# META     }
# META   }
# META }

# CELL ********************

# ============================================================
# ONE-SHOT — Réinitialisation Bronze (DEV, TEST ou PROD)
#   1. vide les transactions + journaux techniques
#   2. recharge les 6 référentiels depuis le dernier Excel déposé dans Files/
# À exécuter cellule seule (jamais en Run all), puis commenter la cellule.
# Ensuite : backfill NB_01_Simulateur, puis dbt build --full-refresh.
# ============================================================
CONFIRMER = True
WS = notebookutils.runtime.context["currentWorkspaceName"]
LH = "LH_Immo_Dev"                  # ← LH_Immo_Dev / LH_Immo_Test / LH_Immo_Prod
CONFIRMATION = "FAB-Immo-Dev"                   # ← retaper le nom du workspace pour autoriser

import pandas as pd
from datetime import datetime
from pyspark.sql.types import StructType, StructField, StringType

RACINE = f"abfss://{WS}@onelake.dfs.fabric.microsoft.com/{LH}.Lakehouse/Files"
def q(t): return f"`{WS}`.`{LH}`.`dbo`.`{t}`"

REFERENTIELS = ["src_agences_regions", "src_conseillers", "src_partenaires_patrimoine",
                "src_produits_investissement", "src_objectifs_commerciaux", "src_security_user_access"]
A_VIDER = [
    "src_commissions", "src_crm_investisseurs", "src_crm_prospects", "src_dossiers_adv",
    "src_evenements_clients", "src_expertise_comptable_lmnp", "src_financements",
    "src_gestion_locative", "src_lots_immobiliers", "src_operations_crowdfunding",
    "src_programmes_immobiliers", "src_reclamations_incidents", "src_reservations_immobilieres",
    "src_revente_biens", "src_souscriptions_pierre_papier", "src_ventes_immobilieres",
    "tech_simulation_run_log", "tech_simulation_agenda", "tech_simulation_anomalies",
]

# --- 1. Fichiers : le plus récent pour chaque référentiel, partout sous Files/
def lister(chemin):
    for f in notebookutils.fs.ls(chemin):
        if f.isDir:
            yield from lister(f.path)
        elif f.name.lower().endswith(".xlsx"):
            yield f

fichiers = {}
for f in lister(RACINE):
    t = f.name[:-5]
    if t in REFERENTIELS and getattr(f, "modifyTime", 0) >= getattr(fichiers.get(t), "modifyTime", -1):
        fichiers[t] = f
assert set(fichiers) == set(REFERENTIELS), f"Fichiers manquants : {set(REFERENTIELS) - set(fichiers)}"

def en_texte(v):
    """Bronze est intégralement varchar : dates en AAAA-MM-JJ, vide -> NULL."""
    if v is None or v is pd.NaT or (isinstance(v, float) and pd.isna(v)):
        return None
    if isinstance(v, pd.Timestamp):
        return v.strftime("%Y-%m-%d")
    return str(v)

existantes = {r.tableName for r in spark.sql(f"SHOW TABLES IN `{WS}`.`{LH}`.`dbo`").collect()}

# --- 2. Aperçu
print("— À vider —")
sauvegarde = []
for t in A_VIDER:
    if t in existantes:
        v = spark.sql(f"DESCRIBE HISTORY {q(t)}").agg({"version": "max"}).first()[0]
        n = spark.table(q(t)).count()
        sauvegarde.append((t, int(v), int(n), datetime.now()))
        print(f"{t:36} v{v:<5} {n:>9} lignes")

print("\n— À charger —")
charges = {}
for t in REFERENTIELS:
    notebookutils.fs.cp(fichiers[t].path, f"file:/tmp/{t}.xlsx")
    pdf = pd.read_excel(f"/tmp/{t}.xlsx", engine="openpyxl")
    charges[t] = pdf
    print(f"{t:36} {len(pdf):>9} lignes   {fichiers[t].path.replace(RACINE, 'Files')}")

# --- 3. Exécution
if CONFIRMER:
    assert CONFIRMATION == WS, "CONFIRMATION doit être égal au nom du workspace"
    if sauvegarde:
                spark.createDataFrame(sauvegarde, "table_name string, version bigint, nb_lignes bigint, saved_at timestamp")\
             .write.mode("append").format("delta").saveAsTable(q("tech_sauvegarde_avant_backfill"))
    for t, *_ in sauvegarde:
        spark.sql(f"DELETE FROM {q(t)}")
    for t, pdf in charges.items():
        rows = [tuple(en_texte(v) for v in r) for r in pdf.itertuples(index=False)]
        sdf = spark.createDataFrame(rows, StructType([StructField(c, StringType(), True) for c in pdf.columns]))
        sdf.write.mode("overwrite").format("delta").option("overwriteSchema", "true").saveAsTable(q(t))
    print(f"\n✅ {LH} : {len(sauvegarde)} tables vidées, {len(charges)} référentiels chargés")
    print("   Suite : NB_01_Simulateur avec DATE_DEBUT='2024-01-02', DATE_FIN='2026-09-25'")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
