module protocol_sui::m_token {
    use sui::table::{Self, Table};
    use sui::coin::{Self, TreasuryCap};
    use sui::object::{UID, ID};
    use protocol_sui::continuous_indexing::{Self, ContinuousIndexing};
    use protocol_sui::ttg_registrar;

    // ============ Constants ============
    
    /// Token decimals (matching Solidity's 6 decimals)
    const DECIMALS: u8 = 6;
    
    /// Token name
    const NAME: vector<u8> = b"M by M^0";
    
    /// Token symbol
    const SYMBOL: vector<u8> = b"M";
    
    // ============ Error Codes ============
    
    /// Error when TTG Registrar ID is invalid
    const EInvalidTTGRegistrar: u64 = 1;
    
    /// Error when account is not an approved earner
    const ENotApprovedEarner: u64 = 2;
    
    /// Error when account is an approved earner (for stopEarning external)
    const EIsApprovedEarner: u64 = 3;
    
    /// Error when balance is insufficient
    const EInsufficientBalance: u64 = 4;
    
    /// Error when amount is insufficient (zero)
    const EInsufficientAmount: u64 = 5;
    
    /// Error when recipient is invalid (zero address)
    const EInvalidRecipient: u64 = 6;
    
    /// Error when mint would overflow principal of total supply
    const EOverflowsPrincipalOfTotalSupply: u64 = 7;

    // ============ Events ============
    
    /// Emitted when an account starts earning
    public struct StartedEarningEvent has copy, drop {
        account: address
    }
    
    /// Emitted when an account stops earning
    public struct StoppedEarningEvent has copy, drop {
        account: address
    }
    
    /// Transfer event (standard ERC20-like)
    public struct TransferEvent has copy, drop {
        from: address,
        to: address,
        amount: u256
    }

    // ============ Structs ============
    
    /// Earning account state - tracks principal amount for earning accounts
    public struct EarningState has store {
        /// Principal amount for this earning account (uint112 → u128)  
        principal_amount: u128
    }
    
    /// Main MToken object - shared object for protocol state management
    public struct MToken has key {
        id: UID,
        
        /// Reference to the TTG Registrar (stored as ID for validation)
        ttg_registrar_id: ID,
        
        /// Total supply of non-earning M tokens (uint240 → u256)
        /// This tracks coins held by non-earning accounts
        total_non_earning_supply: u256,
        
        /// Principal of total earning supply (uint112 → u128)
        /// This tracks the total principal of all earning accounts
        principal_of_total_earning_supply: u128,
        
        /// Continuous indexing state (embedded instead of inherited)
        indexing: ContinuousIndexing,

        /// Mapping of earning accounts to their principal amounts
        /// Non-earning accounts are NOT in this table
        earning_accounts: Table<address, EarningState>
    }
    
    /// The coin type for M token
    public struct M has drop {}
    
    /// One-time witness for module initialization
    public struct M_TOKEN has drop {}
    

    // ============ Initialization ============
    
    /// Module initializer - automatically called when module is published
    /// Creates the M currency using the one-time witness
    fun init(witness: M_TOKEN, ctx: &mut TxContext) {
        // Create the M coin currency using OTW
        let (treasury_cap, metadata) = coin::create_currency(
            witness,  // Use the one-time witness
            DECIMALS,
            SYMBOL,
            NAME,
            b"M token for the M^0 protocol",
            option::none(),  // No icon URL
            ctx
        );
        
        // Freeze metadata to make it immutable and discoverable
        transfer::public_freeze_object(metadata);
        
        // Transfer TreasuryCap to the publisher (will be sent to MinterGateway)
        transfer::public_transfer(treasury_cap, ctx.sender());
    }
    
    /// Create MToken state object - called after module deployment
    /// @param ttg_registrar_id: ID of the TTG Registrar shared object  
    /// @param ctx: Transaction context
    public fun create_mtoken(
        ttg_registrar_id: ID,
        ctx: &mut TxContext
    ) {
        // Create the MToken shared object
        let mtoken = MToken {
            id: object::new(ctx),
            ttg_registrar_id,
            total_non_earning_supply: 0,
            principal_of_total_earning_supply: 0,
            indexing: continuous_indexing::new(ctx),
            earning_accounts: table::new(ctx)
        };
        
        // Share the MToken object
        transfer::share_object(mtoken);
    }

    // ============ Test-Only Functions ============
    
    #[test_only]
    /// Initialize for other modules' tests that expect shared objects
    public fun initialize(ctx: &mut TxContext) {
        // Initialize TTG registrar (it shares itself)
        ttg_registrar::initialize(ctx);
        
        // Get a TTG registrar ID and create MToken using production function
        let dummy_ttg_registrar = ttg_registrar::new_for_testing(ctx);
        let ttg_registrar_id = object::id(&dummy_ttg_registrar);
        
        // Use the actual production function
        create_mtoken(ttg_registrar_id, ctx);
        
        // Clean up dummy
        sui::test_utils::destroy(dummy_ttg_registrar);
    }
    
    #[test_only]
    /// Set total earning supply directly for testing earner rate model
    public fun set_total_earning_supply(mtoken: &mut MToken, amount: u256) {
        mtoken.principal_of_total_earning_supply = (amount as u128);
    }
    
    #[test_only]
    /// Add earning account for testing - simulates what start_earning would do
    public fun add_earning_account_for_testing(mtoken: &mut MToken, account: address, principal: u128) {
        let earning_state = EarningState { principal_amount: principal };
        table::add(&mut mtoken.earning_accounts, account, earning_state);
        mtoken.principal_of_total_earning_supply = mtoken.principal_of_total_earning_supply + principal;
    }
    
    #[test_only]
    /// Create MToken for testing - returns local object instead of sharing
    public fun new_for_testing(ttg_registrar_id: ID, ctx: &mut TxContext): MToken {
        MToken {
            id: object::new(ctx),
            ttg_registrar_id,
            total_non_earning_supply: 0,
            principal_of_total_earning_supply: 0,
            indexing: continuous_indexing::new(ctx),
            earning_accounts: table::new(ctx)
        }
    }
    
    // ============ Capability-Gated Functions ============
    
    /// Mint M tokens - only callable by MinterGateway with TreasuryCap
    /// @param mtoken: The MToken shared object
    /// @param treasury_cap: TreasuryCap for minting coins and access control
    /// @param account: Address to mint tokens to
    /// @param amount: Amount to mint
    public fun mint(
        _mtoken: &mut MToken,
        _treasury_cap: &mut TreasuryCap<M>,
        _account: address,
        _amount: u256
    ) {
        // Access control is implicitly handled by TreasuryCap ownership
        
        // Placeholder - will implement full mint logic
        // This would:
        // 1. Check if account is earning or non-earning
        // 2. Update appropriate supply counters
        // 3. Mint actual coins using treasury_cap
        // 4. Update balances table
        // 5. Emit events
        abort 0
    }
    
    /// Burn M tokens - only callable by MinterGateway with TreasuryCap
    /// @param mtoken: The MToken shared object
    /// @param treasury_cap: TreasuryCap for access control
    /// @param account: Address to burn tokens from
    /// @param amount: Amount to burn
    public fun burn(
        _mtoken: &mut MToken,
        _treasury_cap: &mut TreasuryCap<M>,
        _account: address,
        _amount: u256
    ) {
        // Access control is implicitly handled by TreasuryCap ownership
        
        // Placeholder - will implement full burn logic
        // This would:
        // 1. Check account balance is sufficient
        // 2. Update appropriate supply counters
        // 3. Update balances table
        // 4. Emit events
        // Note: Actual coin burning happens in MinterGateway
        abort 0
    }
    
    // ============ View Functions ============
    
    /// Get the principal balance of an earning account (0 for non-earning accounts)
    /// @param mtoken: Reference to MToken shared object  
    /// @param account: Address to check principal balance for
    /// @return: Principal balance (0 if not earning)
    public fun principal_balance_of(mtoken: &MToken, account: address): u128 {
        if (!table::contains(&mtoken.earning_accounts, account)) {
            return 0
        };
        
        let earning_state = table::borrow(&mtoken.earning_accounts, account);
        earning_state.principal_amount
    }
    
    /// Check if an account is earning
    /// @param mtoken: Reference to MToken shared object
    /// @param account: Address to check earning status for  
    /// @return: True if account is earning, false otherwise
    public fun is_earning(mtoken: &MToken, account: address): bool {
        table::contains(&mtoken.earning_accounts, account)
    }
    
    /// Get the total earning supply (present amount)
    /// @param mtoken: Reference to MToken shared object
    /// @param ctx: Transaction context for timestamp access
    /// @return: Total supply of earning tokens in present value
    public fun total_earning_supply(mtoken: &MToken, ctx: &TxContext): u256 {
        get_present_amount_from_principal(mtoken.principal_of_total_earning_supply, mtoken, ctx)
    }
    
    /// Get the total non-earning supply
    /// @param mtoken: Reference to MToken shared object
    /// @return: Total supply of non-earning tokens
    public fun total_non_earning_supply(mtoken: &MToken): u256 {
        mtoken.total_non_earning_supply
    }
    
    /// Get the total supply (earning + non-earning)
    /// @param mtoken: Reference to MToken shared object
    /// @param ctx: Transaction context for timestamp access
    /// @return: Total supply in present value terms
    public fun total_supply(mtoken: &MToken, ctx: &TxContext): u256 {
        total_non_earning_supply(mtoken) + total_earning_supply(mtoken, ctx)
    }
    
    /// Get the TTG Registrar ID
    public fun ttg_registrar_id(mtoken: &MToken): ID {
        mtoken.ttg_registrar_id
    }
    
    // ============ Internal Helper Functions ============
    
    /// Convert principal amount to present amount using current index
    /// @param principal_amount: Principal amount to convert
    /// @param mtoken: Reference to MToken for accessing current index
    /// @param ctx: Transaction context for timestamp access
    /// @return: Present amount (rounded down)
    fun get_present_amount_from_principal(principal_amount: u128, mtoken: &MToken, ctx: &TxContext): u256 {
        continuous_indexing::get_present_amount_rounded_down(
            principal_amount,
            get_current_index(mtoken, ctx)
        )
    }
    
    /// Convert present amount to principal amount (rounded down - favors protocol)
    /// @param present_amount: Present amount to convert
    /// @param mtoken: Reference to MToken for accessing current index
    /// @param ctx: Transaction context for timestamp access
    /// @return: Principal amount (rounded down)
    fun get_principal_amount_rounded_down(present_amount: u256, mtoken: &MToken, ctx: &TxContext): u128 {
        continuous_indexing::get_principal_amount_rounded_down(
            present_amount,
            get_current_index(mtoken, ctx)
        )
    }
    
    /// Convert present amount to principal amount (rounded up - favors protocol)
    /// @param present_amount: Present amount to convert  
    /// @param mtoken: Reference to MToken for accessing current index
    /// @param ctx: Transaction context for timestamp access
    /// @return: Principal amount (rounded up)
    fun get_principal_amount_rounded_up(present_amount: u256, mtoken: &MToken, ctx: &TxContext): u128 {
        continuous_indexing::get_principal_amount_rounded_up(
            present_amount,
            get_current_index(mtoken, ctx)
        )
    }
    
    /// Get the current index based on latest state and time elapsed
    /// @param mtoken: Reference to MToken for accessing indexing state
    /// @param ctx: Transaction context for timestamp access
    /// @return: Current index value
    fun get_current_index(mtoken: &MToken, ctx: &TxContext): u128 {
        continuous_indexing::calculate_current_index(
            continuous_indexing::latest_index(&mtoken.indexing),
            continuous_indexing::latest_rate(&mtoken.indexing), 
            continuous_indexing::latest_update_timestamp(&mtoken.indexing),
            // Convert milliseconds to seconds for continuous indexing math
            ctx.epoch_timestamp_ms() / 1000
        )
    }
    
}
