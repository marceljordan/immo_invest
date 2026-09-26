{% macro derniere_version(source_table, cle, colonne_date='updated_at') %}
(
    select *
    from (
        select
            s.*,
            row_number() over (
                partition by s.{{ cle }}
                order by try_cast(s.{{ colonne_date }} as datetime2(6)) desc
            ) as _rn_version
        from {{ source_table }} s
    ) v
    where v._rn_version = 1
) src
{% endmacro %}