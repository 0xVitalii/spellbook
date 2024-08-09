{% macro uniswap_v2_forks_trades(
    blockchain = null
    , project = null
    , version = null
    , Pair_evt_Swap = null
    , Factory_evt_PairCreated = null
    , pair_column_name = 'pair'
    , Fork_Mapping = null
    , contracts = null
    )
%}
WITH dexs AS
(
    SELECT
        t.block_number
        , t.block_time
        , t.to AS taker
        , t.contract_address AS maker
        , CASE WHEN amount0Out = UINT256 '0' THEN amount1Out ELSE amount0Out END AS token_bought_amount_raw
        , CASE WHEN amount0In = UINT256 '0' OR amount1Out = UINT256 '0' THEN amount1In ELSE amount0In END AS token_sold_amount_raw
        , CASE WHEN amount0Out = UINT256 '0' THEN f.token1 ELSE f.token0 END AS token_bought_address
        , CASE WHEN amount0In = UINT256 '0' OR amount1Out = UINT256 '0' THEN f.token1 ELSE f.token0 END AS token_sold_address
        , t.contract_address AS project_contract_address
        , t.tx_hash
        , t.index AS evt_index
        , m.project_name
    FROM
        {{ Pair_evt_Swap }} t
    INNER JOIN
        {{ Factory_evt_PairCreated }} f
        ON f.{{ pair_column_name }} = t.contract_address
    LEFT JOIN 
        {{Fork_Mapping}} m
        ON  f.factory_address = f.contract_address
    LEFT JOIN
        {{contracts}} c 
        ON f.contract_address = f.contract_address
    {% if is_incremental() %}
    WHERE
        {{ incremental_predicate('t.block_time') }}
    {% endif %}
)

SELECT
    '{{ blockchain }}' AS blockchain
    , coalesce(c.namespace, m.project_name, concat(cast(varbinary_substring(l.contract_address, 1, 3) as varchar),'-unidentified-fork')) AS project
    , '{{ version }}' AS version
    , CAST(date_trunc('month', dexs.block_time) AS date) AS block_month
    , CAST(date_trunc('day', dexs.block_time) AS date) AS block_date
    , dexs.block_time
    , dexs.block_number
    , dexs.token_bought_amount_raw
    , dexs.token_sold_amount_raw
    , dexs.token_bought_address
    , dexs.token_sold_address
    , dexs.taker
    , dexs.maker
    , dexs.project_contract_address
    , dexs.tx_hash
    , dexs.evt_index
FROM
    dexs

{% endmacro %}