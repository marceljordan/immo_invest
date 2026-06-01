/*
Fichier : models/silver/silver_objectifs_commerciaux.sql

Rôle :
- Créer la table Silver des objectifs commerciaux.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_objectifs_commerciaux

Sortie :
- Crée une table dans le Warehouse :
  silver.objectifs_commerciaux

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Conversion de l’année et du mois en int
- Conversion des objectifs financiers en decimal(18,2)
- Conversion des objectifs de volumes en int
- Normalisation du niveau d’objectif, famille produit et type produit
- Conversion de is_active en bit

Objectif :
- Obtenir une table propre pour comparer objectifs commerciaux et réalisé.
*/

{{ config(alias='objectifs_commerciaux') }}

select
    cast(objectif_id as varchar(50)) as objectif_id,

    try_cast(annee as int) as annee,
    try_cast(mois as int) as mois,
    trim(periode) as periode,

    upper(trim(niveau_objectif)) as niveau_objectif,

    cast(region_id as varchar(50)) as region_id,
    cast(agence_id as varchar(50)) as agence_id,
    cast(conseiller_id as varchar(50)) as conseiller_id,
    cast(partenaire_id as varchar(50)) as partenaire_id,

    upper(trim(famille_produit)) as famille_produit,
    upper(trim(type_produit)) as type_produit,

    try_cast(objectif_ca as decimal(18,2)) as objectif_ca,
    try_cast(objectif_nombre_ventes as int) as objectif_nombre_ventes,
    try_cast(objectif_nombre_reservations as int) as objectif_nombre_reservations,
    try_cast(objectif_montant_souscriptions as decimal(18,2)) as objectif_montant_souscriptions,
    try_cast(objectif_commissions as decimal(18,2)) as objectif_commissions,
    try_cast(objectif_nouveaux_clients as int) as objectif_nouveaux_clients,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_active)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_active

from {{ get_lakehouse() }}.dbo.src_objectifs_commerciaux