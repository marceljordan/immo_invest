/*
Fichier : models/gold/dim_statut.sql

Rôle :
- Créer une dimension Statut transverse.

Actions réalisées :
- Centralise les statuts métier.
- Ajoute une ligne UNKNOWN par domaine de statut.
- Classe chaque statut (TERMINE / EN_COURS / ECHEC) via la liste
  « categories » ci-dessous (règle métier explicite, versionnée avec le modèle).
- Un statut absent de la liste est classé NON_CLASSE (code 0) : un test dbt
  le signale pour qu'il soit ajouté à la liste.
- Génère une surrogate key composite avec dbt_utils.

Objectif :
- Permettre aux facts de pointer vers une dimension statut valide,
  même si le statut source est absent ou non reconnu.
- Porter la classification des statuts comme attribut de dimension
  (et non dans une mesure DAX).
*/

{{ config(alias='dim_statut') }}

with statuts_sources as (

    select 'RESERVATION' as domaine_statut, statut_reservation as statut_value
    from {{ ref('reservations_immobilieres') }}

    union

    select 'VENTE' as domaine_statut, statut_vente as statut_value
    from {{ ref('ventes_immobilieres') }}

    union

    select 'COMMISSION' as domaine_statut, statut_commission as statut_value
    from {{ ref('commissions') }}

    union

    select 'SOUSCRIPTION' as domaine_statut, statut_souscription as statut_value
    from {{ ref('souscriptions_pierre_papier') }}

    union

    select 'CROWDFUNDING' as domaine_statut, statut_operation as statut_value
    from {{ ref('operations_crowdfunding') }}

    union

    select 'FINANCEMENT' as domaine_statut, statut_financement as statut_value
    from {{ ref('financements') }}

    union

    select 'GESTION_LOCATIVE' as domaine_statut, statut_gestion as statut_value
    from {{ ref('gestion_locative') }}

    union

    select 'REVENTE' as domaine_statut, statut_revente as statut_value
    from {{ ref('revente_biens') }}

    union

    select 'DOSSIER_ADV' as domaine_statut, statut_dossier as statut_value
    from {{ ref('dossiers_adv') }}

    union

    select 'RECLAMATION' as domaine_statut, statut_reclamation as statut_value
    from {{ ref('reclamations_incidents') }}

),

statuts_clean as (

    select distinct
        domaine_statut,
        cast(upper(trim(statut_value)) as varchar(100)) as statut_value
    from statuts_sources
    where statut_value is not null

),

unknown_rows as (

    select 'RESERVATION' as domaine_statut, cast('__UNKNOWN__' as varchar(100)) as statut_value
    union all select 'VENTE', cast('__UNKNOWN__' as varchar(100))
    union all select 'COMMISSION', cast('__UNKNOWN__' as varchar(100))
    union all select 'SOUSCRIPTION', cast('__UNKNOWN__' as varchar(100))
    union all select 'CROWDFUNDING', cast('__UNKNOWN__' as varchar(100))
    union all select 'FINANCEMENT', cast('__UNKNOWN__' as varchar(100))
    union all select 'GESTION_LOCATIVE', cast('__UNKNOWN__' as varchar(100))
    union all select 'REVENTE', cast('__UNKNOWN__' as varchar(100))
    union all select 'DOSSIER_ADV', cast('__UNKNOWN__' as varchar(100))
    union all select 'RECLAMATION', cast('__UNKNOWN__' as varchar(100))

),

final as (

    select * from statuts_clean
    union
    select * from unknown_rows

),

-- Règle métier de classification des statuts (tous domaines).
-- Pour ajouter ou reclasser un statut : modifier cette liste.
categories (statut_value, categorie_statut, libelle_categorie, code_couleur) as (

    select 'ACCEPTE', 'TERMINE', 'Terminé / succès', 3
    union all select 'ACTEE', 'TERMINE', 'Terminé / succès', 3
    union all select 'ACCORD PRINCIPE', 'TERMINE', 'Terminé / succès', 3
    union all select 'ACTE SIGNE', 'TERMINE', 'Terminé / succès', 3
    union all select 'ACTIVE', 'TERMINE', 'Terminé / succès', 3
    union all select 'CLOTUREE', 'TERMINE', 'Terminé / succès', 3
    union all select 'LIVREE', 'TERMINE', 'Terminé / succès', 3
    union all select 'MANDAT SIGNE', 'TERMINE', 'Terminé / succès', 3
    union all select 'PAYEE', 'TERMINE', 'Terminé / succès', 3
    union all select 'REMBOURSEE', 'TERMINE', 'Terminé / succès', 3
    union all select 'RESOLUE', 'TERMINE', 'Terminé / succès', 3
    union all select 'SIGNEE', 'TERMINE', 'Terminé / succès', 3
    union all select 'TERMINEE', 'TERMINE', 'Terminé / succès', 3
    union all select 'TRANSFORMEE EN VENTE', 'TERMINE', 'Terminé / succès', 3
    union all select 'VALIDE', 'TERMINE', 'Terminé / succès', 3
    union all select 'VALIDEE', 'TERMINE', 'Terminé / succès', 3
    union all select 'REVENDU', 'TERMINE', 'Terminé / succès', 3
    union all select 'CALCULEE', 'EN_COURS', 'En cours / attente', 2
    union all select 'DEMANDE DEPOSEE', 'EN_COURS', 'En cours / attente', 2
    union all select 'DEMANDE RECUE', 'EN_COURS', 'En cours / attente', 2
    union all select 'EN ATTENTE', 'EN_COURS', 'En cours / attente', 2
    union all select 'EN COMMERCIALISATION', 'EN_COURS', 'En cours / attente', 2
    union all select 'EN COURS', 'EN_COURS', 'En cours / attente', 2
    union all select 'ENVOYE NOTAIRE', 'EN_COURS', 'En cours / attente', 2
    union all select 'OFFRE EMISE', 'EN_COURS', 'En cours / attente', 2
    union all select 'OUVERT', 'EN_COURS', 'En cours / attente', 2
    union all select 'OUVERTE', 'EN_COURS', 'En cours / attente', 2
    union all select 'PIECES EN ATTENTE', 'EN_COURS', 'En cours / attente', 2
    union all select 'RETARD', 'EN_COURS', 'En cours / attente', 2
    union all select 'ABANDONNE', 'ECHEC', 'Échec / blocage', 1
    union all select 'ANNULEE', 'ECHEC', 'Échec / blocage', 1
    union all select 'BLOQUEE', 'ECHEC', 'Échec / blocage', 1
    union all select 'BLOQUE', 'ECHEC', 'Échec / blocage', 1
    union all select 'DEFAUT', 'ECHEC', 'Échec / blocage', 1
    union all select 'ECHEC', 'ECHEC', 'Échec / blocage', 1
    union all select 'EXPIREE', 'ECHEC', 'Échec / blocage', 1
    union all select 'REFUSE', 'ECHEC', 'Échec / blocage', 1
    union all select 'REJETEE', 'ECHEC', 'Échec / blocage', 1

)

select
    {{ dbt_utils.generate_surrogate_key(['f.domaine_statut', 'f.statut_value']) }} as statut_key,
    f.domaine_statut,
    f.statut_value,

    case
        when f.statut_value = '__UNKNOWN__' then 'INCONNU'
        else coalesce(c.categorie_statut, 'NON_CLASSE')
    end as categorie_statut,

    case
        when f.statut_value = '__UNKNOWN__' then 'Inconnu'
        else coalesce(c.libelle_categorie, 'Non classé')
    end as libelle_categorie,

    cast(coalesce(c.code_couleur, 0) as int) as code_couleur

from final f

left join categories c
    on f.statut_value = c.statut_value