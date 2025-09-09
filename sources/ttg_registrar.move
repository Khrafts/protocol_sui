module protocol_sui::ttg_registrar {
    use sui::table::{Self, Table};
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::transfer;
    
    // ============ Constants ============
    
    /// The parameter key for max earner rate
    const MAX_EARNER_RATE_KEY: vector<u8> = b"max_earner_rate";
    
    /// The parameter key for base minter rate
    const BASE_MINTER_RATE_KEY: vector<u8> = b"base_minter_rate";
    
    // ============ Structs ============
    
    /// Dummy TTGRegistrar object for now
    public struct TTGRegistrar has key {
        id: UID,
        config: Table<vector<u8>, u256>,
    }
    
    // ============ Initialization ============
    
    /// Initialize the TTGRegistrar (dummy implementation)
    fun init(ctx: &mut TxContext) {
        let mut config = table::new<vector<u8>, u256>(ctx);
        
        // Set default max earner rate to 10% (1000 basis points)
        table::add(&mut config, MAX_EARNER_RATE_KEY, 1000);
        
        // Set default base minter rate to 5% (500 basis points)
        table::add(&mut config, BASE_MINTER_RATE_KEY, 500);
        
        let registrar = TTGRegistrar {
            id: object::new(ctx),
            config,
        };
        
        transfer::share_object(registrar);
    }
    
    // ============ View Functions ============
    
    /// Get a configuration value by key
    public fun get(registrar: &TTGRegistrar, key: vector<u8>): u256 {
        if (table::contains(&registrar.config, key)) {
            *table::borrow(&registrar.config, key)
        } else {
            0
        }
    }
    
    /// Get the max earner rate specifically
    public fun get_max_earner_rate(registrar: &TTGRegistrar): u256 {
        get(registrar, MAX_EARNER_RATE_KEY)
    }
    
    /// Get the base minter rate specifically
    public fun get_base_minter_rate(registrar: &TTGRegistrar): u256 {
        get(registrar, BASE_MINTER_RATE_KEY)
    }
    
    // ============ Setter Functions (for testing/governance) ============
    
    public fun set(registrar: &mut TTGRegistrar, key: vector<u8>, value: u256) {
        if (table::contains(&registrar.config, key)) {
            table::remove(&mut registrar.config, key);
        };
        table::add(&mut registrar.config, key, value);
    }
    
    public fun set_max_earner_rate(registrar: &mut TTGRegistrar, value: u256) {
        set(registrar, MAX_EARNER_RATE_KEY, value);
    }
    
    public fun set_base_minter_rate(registrar: &mut TTGRegistrar, value: u256) {
        set(registrar, BASE_MINTER_RATE_KEY, value);
    }

    #[test_only]
    public fun new_for_testing(ctx: &mut TxContext): TTGRegistrar {
        let mut config = table::new<vector<u8>, u256>(ctx);
        
        // Set default max earner rate to 10% (1000 basis points)
        table::add(&mut config, MAX_EARNER_RATE_KEY, 1000);
        
        // Set default base minter rate to 5% (500 basis points)
        table::add(&mut config, BASE_MINTER_RATE_KEY, 500);
        
        TTGRegistrar {
            id: object::new(ctx),
            config,
        }
    }
    
    #[test_only]
    public fun initialize(ctx: &mut TxContext) {
        init(ctx);
    }
}