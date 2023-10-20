{{config(
    tags=['dunesql'],
    alias = alias('dao_addresses'))}}

{% set aragon_models = [
ref('aragon_ethereum_app_dao_addresses'),
ref('aragon_ethereum_client_dao_addresses')
] %}


SELECT *

FROM (
    {% for dao_model in aragon_models %}
    SELECT
        blockchain,
        dao_creator_tool, 
        dao, 
        dao_wallet_address,
        created_block_time,
        created_date,
        block_month,
        product
    FROM {{ dao_model }}
    {% if not loop.last %}
    UNION ALL
    {% endif %}
    {% endfor %}
)