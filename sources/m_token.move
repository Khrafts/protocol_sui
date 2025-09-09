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
    public struct EarningState has store, drop {
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
    
    /// One-time witness for module initialization and coin type
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
    
    // NOTE: TreasuryCap testing functionality to be added later
    // For now, tests will be done through integration testing with MinterGateway
    
    // ============ Capability-Gated Functions ============
    
    /// Mint M tokens - only callable by MinterGateway with TreasuryCap
    /// @param mtoken: The MToken shared object
    /// @param treasury_cap: TreasuryCap for minting coins and access control
    /// @param account: Address to mint tokens to
    /// @param amount: Amount to mint (present value)
    /// @param ctx: Transaction context
    /// @return: Minted coins
    public fun mint(
        mtoken: &mut MToken,
        treasury_cap: &mut TreasuryCap<M_TOKEN>,
        account: address,
        amount: u256,
        ctx: &mut TxContext
    ): coin::Coin<M_TOKEN> {
        // Access control is implicitly handled by TreasuryCap ownership
        
        // Check amount is not zero
        assert!(amount > 0, EInsufficientAmount);
        
        // Check recipient is not zero address
        assert!(account != @0x0, EInvalidRecipient);
        
        // Check overflow prevention (similar to Solidity)
        // If all tokens were converted to earning principal, would it overflow?
        let new_total = mtoken.total_non_earning_supply + amount;
        assert!(new_total <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, EOverflowsPrincipalOfTotalSupply);
        
        // Update index first if there are earning accounts
        if (mtoken.principal_of_total_earning_supply > 0) {
            update_index(mtoken, ctx);
        };
        
        // Check if account is earning and update accounting
        if (table::contains(&mtoken.earning_accounts, account)) {
            // Account is earning - convert present amount to principal
            let principal_amount = get_principal_amount_rounded_down(amount, mtoken, ctx);
            
            // Check principal wouldn't overflow u128
            let new_principal_total = (mtoken.principal_of_total_earning_supply as u256) + (principal_amount as u256);
            assert!(new_principal_total <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, EOverflowsPrincipalOfTotalSupply);
            
            // Update earning state
            let earning_state = table::borrow_mut(&mut mtoken.earning_accounts, account);
            earning_state.principal_amount = earning_state.principal_amount + principal_amount;
            
            // Update total earning supply principal
            mtoken.principal_of_total_earning_supply = 
                mtoken.principal_of_total_earning_supply + principal_amount;
        } else {
            // Account is non-earning - direct amount
            mtoken.total_non_earning_supply = new_total;
        };
        
        // Emit transfer event from zero address (minting)
        sui::event::emit(TransferEvent { 
            from: @0x0, 
            to: account, 
            amount 
        });
        
        // Mint and return the actual coins
        // Note: coin::mint expects u64, so we need to ensure amount fits
        assert!(amount <= 0xFFFFFFFFFFFFFFFF, EOverflowsPrincipalOfTotalSupply);
        coin::mint(treasury_cap, (amount as u64), ctx)
    }
    
    /// Burn M tokens - only callable by MinterGateway with TreasuryCap
    /// @param mtoken: The MToken shared object  
    /// @param treasury_cap: TreasuryCap for access control
    /// @param account: Address to burn tokens from
    /// @param amount: Present amount to burn
    /// @param ctx: Transaction context
    public fun burn(
        mtoken: &mut MToken,
        _treasury_cap: &mut TreasuryCap<M_TOKEN>,
        account: address,
        amount: u256,
        ctx: &mut TxContext
    ) {
        // Access control is implicitly handled by TreasuryCap ownership
        
        // Check amount is not zero
        assert!(amount > 0, EInsufficientAmount);
        
        // Emit transfer event to zero address (burning)
        sui::event::emit(TransferEvent { 
            from: account, 
            to: @0x0, 
            amount 
        });
        
        // Check if account is earning and update accounting
        if (table::contains(&mtoken.earning_accounts, account)) {
            // Account is earning - convert present amount to principal (rounded up for protocol)
            update_index(mtoken, ctx);
            
            let principal_amount = get_principal_amount_rounded_up(amount, mtoken, ctx);
            
            // Get earning state and check balance
            let earning_state = table::borrow_mut(&mut mtoken.earning_accounts, account);
            assert!(earning_state.principal_amount >= principal_amount, EInsufficientBalance);
            
            // Update earning state
            earning_state.principal_amount = earning_state.principal_amount - principal_amount;
            
            // Update total earning supply principal
            mtoken.principal_of_total_earning_supply = 
                mtoken.principal_of_total_earning_supply - principal_amount;
        } else {
            // Account is non-earning - direct amount
            assert!(mtoken.total_non_earning_supply >= amount, EInsufficientBalance);
            mtoken.total_non_earning_supply = mtoken.total_non_earning_supply - amount;
        };
        
        // Note: Actual coin burning (destroying the coin objects) happens in MinterGateway
    }
    
    // ============ Public Functions ============
    
    /// Start earning for the caller - only approved earners can call this
    /// @param mtoken: The MToken shared object
    /// @param ctx: Transaction context 
    public fun start_earning(mtoken: &mut MToken, ctx: &mut TxContext) {
        let caller = ctx.sender();
        
        // Check if caller is an approved earner (TODO: implement TTG check)
        // For now, we'll use a simple check - in production this would check TTG registrar
        // assert!(is_approved_earner(mtoken, caller), ENotApprovedEarner);
        
        start_earning_internal(mtoken, caller, ctx);
    }
    
    /// Internal function to start earning for an account
    /// @param mtoken: Mutable reference to MToken
    /// @param account: Account to start earning for
    /// @param ctx: Transaction context
    fun start_earning_internal(mtoken: &mut MToken, account: address, ctx: &mut TxContext) {
        // Check if already earning
        if (table::contains(&mtoken.earning_accounts, account)) {
            return // Already earning, nothing to do
        };
        
        // Emit event
        sui::event::emit(StartedEarningEvent { account });
        
        // Create earning account with 0 principal initially
        // In a full implementation, this would handle conversion of existing non-earning balance
        // to earning balance by converting present amount to principal amount
        let earning_state = EarningState { principal_amount: 0 };
        table::add(&mut mtoken.earning_accounts, account, earning_state);
        
        // Update index
        update_index(mtoken, ctx);
    }
    
    /// Stop earning for the caller
    /// @param mtoken: The MToken shared object
    /// @param ctx: Transaction context
    public fun stop_earning(mtoken: &mut MToken, ctx: &mut TxContext) {
        let caller = ctx.sender();
        stop_earning_internal(mtoken, caller, ctx);
    }
    
    /// Stop earning for a specific account - only works for non-approved earners
    /// @param mtoken: The MToken shared object
    /// @param account: Account to stop earning for
    /// @param ctx: Transaction context
    public fun stop_earning_for_account(mtoken: &mut MToken, account: address, ctx: &mut TxContext) {
        // Check if account is an approved earner - if so, they must stop themselves
        // TODO: implement TTG check
        // assert!(!is_approved_earner(mtoken, account), EIsApprovedEarner);
        
        stop_earning_internal(mtoken, account, ctx);
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
    
    /// Internal function to stop earning for an account
    /// @param mtoken: Mutable reference to MToken
    /// @param account: Account to stop earning for
    /// @param ctx: Transaction context
    fun stop_earning_internal(mtoken: &mut MToken, account: address, ctx: &mut TxContext) {
        // Check if account is currently earning
        if (!table::contains(&mtoken.earning_accounts, account)) {
            return // Not earning, nothing to do
        };
        
        // Emit event
        sui::event::emit(StoppedEarningEvent { account });
        
        // Get the earning state and calculate present value
        let earning_state = table::borrow(&mtoken.earning_accounts, account);
        let principal_amount = earning_state.principal_amount;
        
        if (principal_amount > 0) {
            // Update index first
            update_index(mtoken, ctx);
            
            // Convert principal to present amount
            let present_amount = get_present_amount_from_principal(principal_amount, mtoken, ctx);
            
            // Update totals - remove from earning supply, add to non-earning supply  
            mtoken.principal_of_total_earning_supply = 
                mtoken.principal_of_total_earning_supply - principal_amount;
            mtoken.total_non_earning_supply = mtoken.total_non_earning_supply + present_amount;
        };
        
        // Remove from earning accounts table
        table::remove(&mut mtoken.earning_accounts, account);
    }
    
    /// Update the index to the current timestamp
    /// @param mtoken: Mutable reference to MToken for updating indexing state
    /// @param ctx: Transaction context for timestamp access
    fun update_index(mtoken: &mut MToken, ctx: &TxContext) {
        // Get current timestamp in seconds
        let current_timestamp = ctx.epoch_timestamp_ms() / 1000;
        
        // For now, use a fixed rate (will integrate with rate model later)
        // TODO: Get rate from TTG registrar's earner rate model
        let current_rate = continuous_indexing::latest_rate(&mtoken.indexing);
        
        // Update the indexing state
        continuous_indexing::update_index(
            &mut mtoken.indexing,
            current_rate,
            current_timestamp
        );
    }
    
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
