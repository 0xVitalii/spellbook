{{ config(

        schema = 'dex_mass_decoding_ethereum',
        alias = 'uniswap_v2_base_trades',
        partition_by = ['block_month'],
        materialized = 'incremental',
        file_format = 'delta',
        incremental_strategy = 'merge',
        unique_key = ['tx_hash', 'evt_index', 'token_bought_address', 'token_sold_address'],
        incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
        )
}}

{{uniswap_v2_forks_trades(
        blockchain = ethereum
        , version = 'unknown'
        , Pair_evt_Swap = ref('uniswap_v2_pool_decoding_ethereum')
        , Factory_evt_PairCreated = ref('uniswap_v2_factory_decoding_ethereum')
        , pair_column_name = 'pair'
        , Fork_Mapping = ref('uniswap_v2_fork_mapping_ethereum')
)}}