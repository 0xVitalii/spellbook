{{ config(
     tags=['legacy'],
     schema = 'gas_ethereum',
     alias = alias('fees_traces', legacy_model=True),
     materialized = 'view'
    )
}}

WITH traces AS (
     SELECT traces.block_time
     , traces.block_number
     , traces.tx_hash
     , MAX(traces.from) AS trace_from
     , MAX(traces.to) AS trace_to
     , traces.trace
     , MAX(traces.input) AS trace_input
     , substring(MAX(traces.input),1,10) AS trace_method
     , SUM(traces.gas_used_original) AS gas_used_original
     , SUM(traces.gas_used_trace) AS gas_used_trace
     , MAX(traces.trace_type) AS trace_type
     , MAX(traces.trace_value) AS trace_value
     , MAX(traces.trace_success) AS trace_success
     , MAX(traces.tx_success) AS tx_success
     FROM (
          SELECT from
          , to
          , tx_hash
          , trace_address AS trace
          , gas_used AS gas_used_original
          , gas_used AS gas_used_trace
          , block_time
          , block_number
          , input
          , type AS trace_type
          , value AS trace_value
          , success AS trace_success
          , tx_success
          FROM {{ source('ethereum','traces') }}
          
          UNION ALL
          
          SELECT CAST(NULL AS varchar(1)) AS from 
          , CAST(NULL AS varchar(1)) AS to 
          , tx_hash
          , slice(trace_address, 1, cardinality(trace_address) - 1) AS trace
          , CAST(NULL AS double) AS gas_used_original
          , -gas_used AS gas_used_trace
          , block_time
          , block_number
          , CAST(NULL AS varchar(1)) AS input
          , CAST(NULL AS varchar(1)) AS trace_type
          , CAST(NULL AS varchar(1)) AS trace_value
          , CAST(NULL AS boolean) AS trace_success
          , CAST(NULL AS boolean) AS tx_success
          FROM {{ source('ethereum','traces') }}
          WHERE cardinality(trace_address) > 0
          ) traces
     GROUP BY traces.tx_hash, traces.trace, traces.block_time, traces.block_number
     )

SELECT 'ethereum' AS blockchain
, traces.block_time
, date_trunc('day', traces.block_time) AS block_date
, traces.block_number
, traces.tx_hash
, traces.trace_from
, traces.trace_to
, txs.from AS tx_from
, txs.to AS tx_to
, traces.trace
, traces.trace_method
, substring(txs.data,1,10) AS tx_method
, traces.trace_input
, traces.gas_used_original
, traces.gas_used_trace
, txs.gas_used AS tx_gas_used
, traces.gas_used_original/txs.gas_used AS gas_used_original_percentage
, traces.gas_used_trace/txs.gas_used AS gas_used_trace_percentage
, txs.gas_price AS tx_gas_price
, traces.trace_type
, traces.trace_value
, traces.trace_success
, traces.tx_success
, (traces.gas_used_original*txs.gas_price)/POWER(10, 18) AS gas_fee_spent_original
, (pu.price*traces.gas_used_original*txs.gas_price)/POWER(10, 18) AS gas_fee_spent_original_usd
, (traces.gas_used_trace*txs.gas_price)/POWER(10, 18) AS gas_fee_spent_trace
, (pu.price*traces.gas_used_trace*txs.gas_price)/POWER(10, 18) AS gas_fee_spent_trace_usd
FROM traces
INNER JOIN {{ source('ethereum','transactions') }} txs ON txs.block_time=traces.block_time
     AND txs.hash=traces.tx_hash
LEFT JOIN {{ source('prices', 'usd') }} pu ON pu.minute=date_trunc('minute', traces.block_time)
     AND pu.blockchain='ethereum'
     AND pu.contract_address='0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'