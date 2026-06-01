{% macro get_lakehouse() %}
  {% if target.name == 'test' %}
    LH_Immo_Test
  {% elif target.name == 'prod' %}
    LH_Immo_Prod
  {% else %}
    LH_Immo_Dev
  {% endif %}
{% endmacro %}