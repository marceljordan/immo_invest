/*
Fichier : models/silver/silver_produits_investissement.sql

Rôle :
- Créer la table Silver des produits d’investissement.

Entrée :
- Lit la table Bronze du Lakehouse :
  LH_Immo_Dev.dbo.src_produits_investissement

Sortie :
- Crée une table dans le Warehouse :
  silver.produits_investissement

Actions réalisées :
- Conversion des identifiants en varchar(50)
- Normalisation des familles, types, fiscalités et niveaux de risque
- Conversion des rendements et frais en decimal
- Conversion des montants minimums en decimal(18,2)
- Conversion des dates de commercialisation en date
- Conversion de is_active en bit

Objectif :
- Obtenir une table propre des produits pour construire la dimension produit et analyser les performances par famille d’investissement.
*/

{{ config(alias='produits_investissement') }}

select
    cast(produit_id as varchar(50)) as produit_id,

    trim(nom_produit) as nom_produit,
    upper(trim(famille_produit)) as famille_produit,
    upper(trim(type_produit)) as type_produit,
    upper(trim(sous_type_produit)) as sous_type_produit,
    upper(trim(fiscalite)) as fiscalite,
    upper(trim(niveau_risque)) as niveau_risque,

    trim(duree_recommandee) as duree_recommandee,

    try_cast(rendement_cible_annuel as decimal(9,4)) as rendement_cible_annuel,
    try_cast(montant_minimum_investissement as decimal(18,2)) as montant_minimum_investissement,
    try_cast(frais_entree as decimal(9,4)) as frais_entree,
    try_cast(frais_gestion_annuels as decimal(9,4)) as frais_gestion_annuels,
    try_cast(frais_sortie as decimal(9,4)) as frais_sortie,

    cast(societe_gestion_id as varchar(50)) as societe_gestion_id,
    cast(promoteur_id as varchar(50)) as promoteur_id,

    upper(trim(statut_commercialisation)) as statut_commercialisation,

    try_cast(date_debut_commercialisation as date) as date_debut_commercialisation,
    try_cast(date_fin_commercialisation as date) as date_fin_commercialisation,

    try_cast(created_at as datetime2(6)) as created_at,
    try_cast(updated_at as datetime2(6)) as updated_at,

    case
        when lower(trim(is_active)) in ('1', 'true', 'oui', 'yes') then cast(1 as bit)
        else cast(0 as bit)
    end as is_active

from LH_Immo_Dev.dbo.src_produits_investissement