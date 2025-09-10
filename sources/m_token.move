module protocol_sui::m_token {
    use sui::table::{Self, Table};
    use sui::coin::{Self, TreasuryCap, Coin};
    use sui::transfer;
    use sui::object::{UID, ID};
    use protocol_sui::continuous_indexing::{Self, ContinuousIndexing};
    use protocol_sui::ttg_registrar;
    use std::option;

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
        principal_amount: u128,
        /// Last index at which interest was claimed (for calculating accrued interest)
        last_claim_index: u128
    }
    
    /// Main MToken state - holds the earning/non-earning tracking
    public struct MTokenState has store {
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
    
    /// Protocol shared object that holds both state and treasury cap
    /// This ensures only protocol functions can mint/burn tokens
    public struct MTokenProtocol has key {
        id: UID,
        /// The MToken state
        state: MTokenState,
        /// The treasury cap - locked here, can never be extracted
        treasury_cap: TreasuryCap<M_TOKEN>
    }
    
    /// One-time witness for module initialization and coin type
    public struct M_TOKEN has drop {}
    
    /// Capability for earning management - allows holder to start/stop earning for approved accounts
    /// This is created during init and sent to the protocol owner
    public struct EarningCap has key, store {
        id: UID
    }
    
    /// Capability for minting/burning tokens - allows holder to mint/burn M tokens
    /// This is created during init and sent to the minter gateway
    public struct MinterCap has key, store {
        id: UID
    }
    

    // ============ Initialization ============
    
    /// Module initializer - automatically called when module is published
    /// Creates the M currency and protocol object
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
        
        // Create the EarningCap and send to the deployer
        let earning_cap = EarningCap {
            id: object::new(ctx)
        };
        transfer::public_transfer(earning_cap, ctx.sender());
        
        // Create the MinterCap and send to the deployer (they will transfer to minter gateway)
        let minter_cap = MinterCap {
            id: object::new(ctx)
        };
        transfer::public_transfer(minter_cap, ctx.sender());
        
        // Note: We don't create the protocol here since we need ttg_registrar_id
        // The treasury_cap will be passed to create_protocol function
        transfer::public_transfer(treasury_cap, ctx.sender());
    }
    
    /// Create the protocol object with locked treasury cap
    /// This should be called once after deployment with the treasury cap
    /// @param treasury_cap: The treasury cap from init
    /// @param ttg_registrar_id: ID of the TTG Registrar shared object
    /// @param ctx: Transaction context
    public fun create_protocol(
        treasury_cap: TreasuryCap<M_TOKEN>,
        ttg_registrar_id: ID,
        ctx: &mut TxContext
    ) {
        // Create the MToken state
        let state = MTokenState {
            ttg_registrar_id,
            total_non_earning_supply: 0,
            principal_of_total_earning_supply: 0,
            indexing: continuous_indexing::new(ctx),
            earning_accounts: table::new(ctx)
        };
        
        // Create the protocol object with locked treasury cap
        let protocol = MTokenProtocol {
            id: object::new(ctx),
            state,
            treasury_cap  // Permanently locked here
        };
        
        // Share the protocol object
        transfer::share_object(protocol);
    }

    // ============ Test-Only Functions ============
    
    #[test_only]
    /// Create an EarningCap for testing
    public fun new_earning_cap_for_testing(ctx: &mut TxContext): EarningCap {
        EarningCap {
            id: object::new(ctx)
        }
    }
    
    #[test_only]
    /// Create a MinterCap for testing
    public fun new_minter_cap_for_testing(ctx: &mut TxContext): MinterCap {
        MinterCap {
            id: object::new(ctx)
        }
    }
    
    #[test_only]
    /// Initialize for other modules' tests that expect shared objects
    public fun initialize(ctx: &mut TxContext) {
        // Initialize TTG registrar (it shares itself)
        ttg_registrar::initialize(ctx);
        
        // Get a TTG registrar ID and create MToken using production function
        let dummy_ttg_registrar = ttg_registrar::new_for_testing(ctx);
        let ttg_registrar_id = object::id(&dummy_ttg_registrar);
        
        // Create a treasury cap for testing
        let (treasury_cap, metadata) = coin::create_currency<M_TOKEN>(
            M_TOKEN {}, 
            9,
            b"M",
            b"M Token",
            b"The M protocol token on Sui",
            option::none(),
            ctx
        );
        
        // Use the actual production function
        create_protocol(treasury_cap, ttg_registrar_id, ctx);
        
        // Clean up dummy and metadata
        sui::test_utils::destroy(dummy_ttg_registrar);
        transfer::public_transfer(metadata, ctx.sender());
    }
    
    #[test_only]
    /// Set total earning supply directly for testing earner rate model
    public fun set_total_earning_supply(state: &mut MTokenState, amount: u256) {
        state.principal_of_total_earning_supply = (amount as u128);
    }
    
    #[test_only]
    /// Set total earning supply directly for testing earner rate model (protocol wrapper)
    public fun set_total_earning_supply_protocol(protocol: &mut MTokenProtocol, amount: u256) {
        protocol.state.principal_of_total_earning_supply = (amount as u128);
    }
    
    #[test_only]
    /// Add earning account for testing - simulates what start_earning would do
    public fun add_earning_account_for_testing(protocol: &mut MTokenProtocol, account: address, principal: u128) {
        let earning_state = EarningState { 
            principal_amount: principal,
            last_claim_index: continuous_indexing::latest_index(&protocol.state.indexing)
        };
        table::add(&mut protocol.state.earning_accounts, account, earning_state);
        protocol.state.principal_of_total_earning_supply = protocol.state.principal_of_total_earning_supply + principal;
    }
    
    #[test_only]
    /// Add non-earning amount for testing - simulates non-earning balance
    public fun add_non_earning_amount_for_testing(protocol: &mut MTokenProtocol, amount: u256) {
        protocol.state.total_non_earning_supply = protocol.state.total_non_earning_supply + amount;
    }
    
    #[test_only]
    /// Get mutable state for testing
    public fun state_mut_for_testing(protocol: &mut MTokenProtocol): &mut MTokenState {
        &mut protocol.state
    }
    
    #[test_only]
    /// Get immutable state for testing  
    public fun state_for_testing(protocol: &MTokenProtocol): &MTokenState {
        &protocol.state
    }
    
    #[test_only]
    /// Create protocol for testing - returns local object instead of sharing
    public fun new_for_testing(ttg_registrar_id: ID, ctx: &mut TxContext): MTokenProtocol {
        use sui::test_utils;
        
        // Create treasury cap for testing
        let (treasury_cap, metadata) = coin::create_currency(
            M_TOKEN {},  
            DECIMALS,
            SYMBOL,
            NAME,
            b"M token for the M^0 protocol",
            option::none(),
            ctx
        );
        
        test_utils::destroy(metadata);
        
        // Create the MToken state
        let state = MTokenState {
            ttg_registrar_id,
            total_non_earning_supply: 0,
            principal_of_total_earning_supply: 0,
            indexing: continuous_indexing::new(ctx),
            earning_accounts: table::new(ctx)
        };
        
        // Create the protocol object with locked treasury cap
        MTokenProtocol {
            id: object::new(ctx),
            state,
            treasury_cap
        }
    }
    
    // NOTE: The TreasuryCap is now locked inside the MTokenProtocol shared object
    // This ensures secure access control while enabling protocol functionality
    
    // ============ Capability-Gated Functions ============
    
    /// Mint M tokens - only callable with MinterCap
    /// @param protocol: The MTokenProtocol shared object with locked TreasuryCap
    /// @param _cap: MinterCap proving authorization to mint
    /// @param account: Address to mint tokens to
    /// @param amount: Amount to mint (present value)
    /// @param ctx: Transaction context
    /// @return: Minted coins
    public fun mint(
        protocol: &mut MTokenProtocol,
        _cap: &MinterCap,
        account: address,
        amount: u256,
        ctx: &mut TxContext
    ): coin::Coin<M_TOKEN> {
        // Access control handled by MinterCap requirement
        
        // Check amount is not zero
        assert!(amount > 0, EInsufficientAmount);
        
        // Check recipient is not zero address
        assert!(account != @0x0, EInvalidRecipient);
        
        // Check overflow prevention (similar to Solidity)
        // If all tokens were converted to earning principal, would it overflow?
        let new_total = protocol.state.total_non_earning_supply + amount;
        assert!(new_total <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, EOverflowsPrincipalOfTotalSupply);
        
        // Update index first if there are earning accounts
        if (protocol.state.principal_of_total_earning_supply > 0) {
            update_index(&mut protocol.state, ctx);
        };
        
        // Check if account is earning and update accounting
        if (table::contains(&protocol.state.earning_accounts, account)) {
            // Account is earning - convert present amount to principal
            let principal_amount = get_principal_amount_rounded_down(amount, &protocol.state, ctx);
            
            // Check principal wouldn't overflow u128
            let new_principal_total = (protocol.state.principal_of_total_earning_supply as u256) + (principal_amount as u256);
            assert!(new_principal_total <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, EOverflowsPrincipalOfTotalSupply);
            
            // Update earning state
            let earning_state = table::borrow_mut(&mut protocol.state.earning_accounts, account);
            earning_state.principal_amount = earning_state.principal_amount + principal_amount;
            
            // Update total earning supply principal
            protocol.state.principal_of_total_earning_supply = 
                protocol.state.principal_of_total_earning_supply + principal_amount;
        } else {
            // Account is non-earning - direct amount
            protocol.state.total_non_earning_supply = new_total;
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
        coin::mint(&mut protocol.treasury_cap, (amount as u64), ctx)
    }
    
    /// Burn M tokens - only callable with MinterCap
    /// @param protocol: The MTokenProtocol shared object with locked TreasuryCap
    /// @param _cap: MinterCap proving authorization to burn
    /// @param account: Address to burn tokens from
    /// @param amount: Present amount to burn
    /// @param ctx: Transaction context
    public fun burn(
        protocol: &mut MTokenProtocol,
        _cap: &MinterCap,
        account: address,
        amount: u256,
        ctx: &mut TxContext
    ) {
        // Access control handled by MinterCap requirement
        
        // Check amount is not zero
        assert!(amount > 0, EInsufficientAmount);
        
        // Emit transfer event to zero address (burning)
        sui::event::emit(TransferEvent { 
            from: account, 
            to: @0x0, 
            amount 
        });
        
        // Check if account is earning and update accounting
        if (table::contains(&protocol.state.earning_accounts, account)) {
            // Account is earning - convert present amount to principal (rounded up for protocol)
            update_index(&mut protocol.state, ctx);
            
            let principal_amount = get_principal_amount_rounded_up(amount, &protocol.state, ctx);
            
            // Get earning state and check balance
            let earning_state = table::borrow_mut(&mut protocol.state.earning_accounts, account);
            assert!(earning_state.principal_amount >= principal_amount, EInsufficientBalance);
            
            // Update earning state
            earning_state.principal_amount = earning_state.principal_amount - principal_amount;
            
            // Update total earning supply principal
            protocol.state.principal_of_total_earning_supply = 
                protocol.state.principal_of_total_earning_supply - principal_amount;
        } else {
            // Account is non-earning - direct amount
            assert!(protocol.state.total_non_earning_supply >= amount, EInsufficientBalance);
            protocol.state.total_non_earning_supply = protocol.state.total_non_earning_supply - amount;
        };
        
        // Note: Actual coin burning (destroying the coin objects) happens in MinterGateway
    }
    
    // ============ Public Functions ============
    
    /// Start earning for an account - requires EarningCap
    /// @param protocol: The MTokenProtocol shared object
    /// @param _cap: The EarningCap capability (proves authorization)
    /// @param account: Account to start earning for
    /// @param balance: Current coin balance of the account (fetched client-side)
    /// @param ctx: Transaction context
    public fun start_earning(
        protocol: &mut MTokenProtocol,
        _cap: &EarningCap,
        account: address,
        balance: u64,
        ctx: &mut TxContext
    ) {
        // Check if account is an approved earner (TODO: implement TTG check)
        // For now, we'll use a simple check - in production this would check TTG registrar
        // assert!(is_approved_earner(protocol, account), ENotApprovedEarner);
        
        start_earning_internal(&mut protocol.state, account, balance, ctx);
    }
    
    /// Internal function to start earning for an account
    /// @param state: Mutable reference to MTokenState
    /// @param account: Account to start earning for
    /// @param amount: Present amount to convert to earning principal
    /// @param ctx: Transaction context
    fun start_earning_internal(state: &mut MTokenState, account: address, amount: u64, ctx: &mut TxContext) {
        // Check if already earning
        if (table::contains(&state.earning_accounts, account)) {
            return // Already earning, nothing to do
        };
        
        // Emit event
        sui::event::emit(StartedEarningEvent { account });
        
        // Update index first
        update_index(state, ctx);
        
        // Convert present amount to principal (rounded down favors protocol)
        let principal_amount = if (amount > 0) {
            let present_amount = (amount as u256);
            // Subtract from non-earning supply
            assert!(state.total_non_earning_supply >= present_amount, EInsufficientBalance);
            state.total_non_earning_supply = state.total_non_earning_supply - present_amount;
            
            // Convert to principal amount
            get_principal_amount_rounded_down(present_amount, state, ctx)
        } else {
            0
        };
        
        // Create earning account
        let earning_state = EarningState { 
            principal_amount,
            last_claim_index: get_current_index(state, ctx)
        };
        table::add(&mut state.earning_accounts, account, earning_state);
        
        // Add to earning supply principal
        state.principal_of_total_earning_supply = state.principal_of_total_earning_supply + principal_amount;
    }
    
    /// Start earning for the caller (self) - no cap required but must be approved earner
    /// @param protocol: The MTokenProtocol shared object
    /// @param balance: Current coin balance of the caller (fetched client-side)
    /// @param ctx: Transaction context
    public fun start_earning_self(
        protocol: &mut MTokenProtocol,
        balance: u64,
        ctx: &mut TxContext
    ) {
        let caller = ctx.sender();
        
        // Check if caller is an approved earner (TODO: implement TTG check)
        // assert!(is_approved_earner(protocol, caller), ENotApprovedEarner);
        
        start_earning_internal(&mut protocol.state, caller, balance, ctx);
    }
    
    /// Stop earning for the caller (self) - no cap required
    /// @param protocol: The MTokenProtocol shared object
    /// @param ctx: Transaction context
    /// @return: (present_value, principal_amount) - values for client-side handling
    public fun stop_earning_self(
        protocol: &mut MTokenProtocol,
        ctx: &mut TxContext
    ): (u64, u128) {
        let caller = ctx.sender();
        stop_earning_internal(&mut protocol.state, caller, ctx)
    }
    
    /// Stop earning for an account - requires EarningCap
    /// @param protocol: The MTokenProtocol shared object
    /// @param _cap: The EarningCap capability (proves authorization)
    /// @param account: Account to stop earning for
    /// @param ctx: Transaction context
    /// @return: (present_value, principal_amount) - the present value that should be minted and the principal that was removed
    public fun stop_earning(
        protocol: &mut MTokenProtocol,
        _cap: &EarningCap,
        account: address,
        ctx: &mut TxContext
    ): (u64, u128) {
        // Can stop earning for any account with the cap (admin function)
        // In production, might want to add restriction for approved earners
        // assert!(!is_approved_earner(protocol, account), EIsApprovedEarner);
        
        stop_earning_internal(&mut protocol.state, account, ctx)
    }
    
    /// Internal function to stop earning for an account
    /// @param state: Mutable reference to MTokenState
    /// @param account: Account to stop earning for
    /// @param ctx: Transaction context
    /// @return: (present_value, principal_amount) - values for client-side handling
    fun stop_earning_internal(state: &mut MTokenState, account: address, ctx: &mut TxContext): (u64, u128) {
        // Check if account is currently earning
        if (!table::contains(&state.earning_accounts, account)) {
            // Not earning, return zero values
            return (0, 0)
        };
        
        // Emit event
        sui::event::emit(StoppedEarningEvent { account });
        
        // Update index first
        update_index(state, ctx);
        
        // Get the earning state and calculate present value
        let earning_state = table::borrow(&state.earning_accounts, account);
        let principal_amount = earning_state.principal_amount;
        
        let present_amount = if (principal_amount > 0) {
            // Convert principal to present amount
            let present_amount = get_present_amount_from_principal(principal_amount, state, ctx);
            
            // Update totals - remove from earning supply, add to non-earning supply  
            state.principal_of_total_earning_supply = 
                state.principal_of_total_earning_supply - principal_amount;
            state.total_non_earning_supply = state.total_non_earning_supply + present_amount;
            
            present_amount
        } else {
            0
        };
        
        // Remove from earning accounts table
        table::remove(&mut state.earning_accounts, account);
        
        // Return the present amount and principal for client-side handling
        assert!(present_amount <= 0xFFFFFFFFFFFFFFFF, EOverflowsPrincipalOfTotalSupply);
        ((present_amount as u64), principal_amount)
    }

    // ============ View Functions ============
    
    /// Get the principal balance of an earning account (0 for non-earning accounts)
    /// @param protocol: Reference to MTokenProtocol shared object  
    /// @param account: Address to check principal balance for
    /// @return: Principal balance (0 if not earning)
    public fun principal_balance_of(protocol: &MTokenProtocol, account: address): u128 {
        if (!table::contains(&protocol.state.earning_accounts, account)) {
            return 0
        };
        
        let earning_state = table::borrow(&protocol.state.earning_accounts, account);
        earning_state.principal_amount
    }
    
    /// Check if an account is earning
    /// @param protocol: Reference to MTokenProtocol shared object
    /// @param account: Address to check earning status for  
    /// @return: True if account is earning, false otherwise
    public fun is_earning(protocol: &MTokenProtocol, account: address): bool {
        table::contains(&protocol.state.earning_accounts, account)
    }
    
    /// Get the total earning supply (present amount)
    /// @param protocol: Reference to MTokenProtocol shared object
    /// @param ctx: Transaction context for timestamp access
    /// @return: Total supply of earning tokens in present value
    public fun total_earning_supply(protocol: &MTokenProtocol, ctx: &TxContext): u256 {
        get_present_amount_from_principal(protocol.state.principal_of_total_earning_supply, &protocol.state, ctx)
    }
    
    /// Get the total earning supply (present amount) from state directly
    /// @param state: Reference to MTokenState
    /// @param ctx: Transaction context for timestamp access
    /// @return: Total supply of earning tokens in present value
    public fun total_earning_supply_from_state(state: &MTokenState, ctx: &TxContext): u256 {
        get_present_amount_from_principal(state.principal_of_total_earning_supply, state, ctx)
    }
    
    /// Get the total non-earning supply
    /// @param protocol: Reference to MTokenProtocol shared object
    /// @return: Total supply of non-earning tokens
    public fun total_non_earning_supply(protocol: &MTokenProtocol): u256 {
        protocol.state.total_non_earning_supply
    }
    
    /// Get the total supply (earning + non-earning)
    /// @param protocol: Reference to MTokenProtocol shared object
    /// @param ctx: Transaction context for timestamp access
    /// @return: Total supply in present value terms
    public fun total_supply(protocol: &MTokenProtocol, ctx: &TxContext): u256 {
        total_non_earning_supply(protocol) + total_earning_supply(protocol, ctx)
    }
    
    /// Get the TTG Registrar ID
    public fun ttg_registrar_id(protocol: &MTokenProtocol): ID {
        protocol.state.ttg_registrar_id
    }
    
    /// Get a reference to the internal state
    public fun get_state(protocol: &MTokenProtocol): &MTokenState {
        &protocol.state
    }
    
    /// Update index using externally calculated rate (from rate model)
    /// @param protocol: Mutable reference to MTokenProtocol
    /// @param rate: The rate to use (calculated by external caller using rate model)
    /// @param ctx: Transaction context
    public fun update_index_with_external_rate(
        protocol: &mut MTokenProtocol,
        rate: u32,
        ctx: &TxContext
    ) {
        update_index_with_rate(&mut protocol.state, ctx, option::some(rate));
    }
    
    // ============ Internal Helper Functions ============
    
    /// Update the index to the current timestamp
    /// @param state: Mutable reference to MTokenState for updating indexing state
    /// @param ctx: Transaction context for timestamp access
    fun update_index(state: &mut MTokenState, ctx: &TxContext) {
        update_index_with_rate(state, ctx, option::none())
    }
    
    /// Update the index with a specific rate (for external rate model integration)
    /// @param state: Mutable reference to MTokenState for updating indexing state
    /// @param ctx: Transaction context for timestamp access
    /// @param rate_override: Optional rate to use instead of fetching from rate model
    public fun update_index_with_rate(state: &mut MTokenState, ctx: &TxContext, rate_override: option::Option<u32>) {
        // Get current timestamp in seconds
        let current_timestamp = ctx.epoch_timestamp_ms() / 1000;
        
        // Use provided rate or fall back to current rate
        let current_rate = if (option::is_some(&rate_override)) {
            option::destroy_some(rate_override)
        } else {
            // TODO: This could be enhanced to integrate with rate model
            // For now, use the latest rate from indexing state
            continuous_indexing::latest_rate(&state.indexing)
        };
        
        // Update the indexing state
        continuous_indexing::update_index(
            &mut state.indexing,
            current_rate,
            current_timestamp
        );
    }
    
    /// Convert principal amount to present amount using current index
    /// @param principal_amount: Principal amount to convert
    /// @param state: Reference to MTokenState for accessing current index
    /// @param ctx: Transaction context for timestamp access
    /// @return: Present amount (rounded down)
    fun get_present_amount_from_principal(principal_amount: u128, state: &MTokenState, ctx: &TxContext): u256 {
        continuous_indexing::get_present_amount_rounded_down(
            principal_amount,
            get_current_index(state, ctx)
        )
    }
    
    /// Convert present amount to principal amount (rounded down - favors protocol)
    /// @param present_amount: Present amount to convert
    /// @param state: Reference to MTokenState for accessing current index
    /// @param ctx: Transaction context for timestamp access
    /// @return: Principal amount (rounded down)
    fun get_principal_amount_rounded_down(present_amount: u256, state: &MTokenState, ctx: &TxContext): u128 {
        continuous_indexing::get_principal_amount_rounded_down(
            present_amount,
            get_current_index(state, ctx)
        )
    }
    
    /// Convert present amount to principal amount (rounded up - favors protocol)
    /// @param present_amount: Present amount to convert  
    /// @param state: Reference to MTokenState for accessing current index
    /// @param ctx: Transaction context for timestamp access
    /// @return: Principal amount (rounded up)
    fun get_principal_amount_rounded_up(present_amount: u256, state: &MTokenState, ctx: &TxContext): u128 {
        continuous_indexing::get_principal_amount_rounded_up(
            present_amount,
            get_current_index(state, ctx)
        )
    }
    
    /// Get the current index based on latest state and time elapsed
    /// @param state: Reference to MTokenState for accessing indexing state
    /// @param ctx: Transaction context for timestamp access
    /// @return: Current index value
    fun get_current_index(state: &MTokenState, ctx: &TxContext): u128 {
        continuous_indexing::calculate_current_index(
            continuous_indexing::latest_index(&state.indexing),
            continuous_indexing::latest_rate(&state.indexing), 
            continuous_indexing::latest_update_timestamp(&state.indexing),
            // Convert milliseconds to seconds for continuous indexing math
            ctx.epoch_timestamp_ms() / 1000
        )
    }
    
    // ============ Claim Functions ============
    
    /// Calculate accrued interest for an earning account
    /// @param protocol: Reference to MTokenProtocol
    /// @param account: Account to calculate interest for
    /// @param ctx: Transaction context
    /// @return: Amount of accrued interest in present value
    public fun calculate_accrued_interest(protocol: &MTokenProtocol, account: address, ctx: &TxContext): u64 {
        if (!table::contains(&protocol.state.earning_accounts, account)) {
            return 0
        };
        
        let earning_state = table::borrow(&protocol.state.earning_accounts, account);
        let current_index = get_current_index(&protocol.state, ctx);
        
        // If no time has passed or no principal, no interest accrued
        if (current_index <= earning_state.last_claim_index || earning_state.principal_amount == 0) {
            return 0
        };
        
        // Calculate present value at current index
        let current_present_value = continuous_indexing::get_present_amount_rounded_down(
            earning_state.principal_amount,
            current_index
        );
        
        // Calculate present value at last claim index
        let last_claim_present_value = continuous_indexing::get_present_amount_rounded_down(
            earning_state.principal_amount,
            earning_state.last_claim_index
        );
        
        // Accrued interest is the difference
        if (current_present_value > last_claim_present_value) {
            ((current_present_value - last_claim_present_value) as u64)
        } else {
            0
        }
    }
    
    /// Claim accrued interest for an earning account
    /// @param protocol: Mutable reference to MTokenProtocol
    /// @param account: Account to claim interest for
    /// @param ctx: Transaction context
    /// @return: Coin with claimed interest
    public fun claim_interest(
        protocol: &mut MTokenProtocol,
        account: address,
        ctx: &mut TxContext
    ): Coin<M_TOKEN> {
        // Calculate accrued interest
        let accrued_amount = calculate_accrued_interest(protocol, account, ctx);
        
        if (accrued_amount == 0) {
            return coin::zero<M_TOKEN>(ctx)
        };
        
        // Update the earning state's last claim index
        let current_index = get_current_index(&protocol.state, ctx);
        let earning_state = table::borrow_mut(&mut protocol.state.earning_accounts, account);
        earning_state.last_claim_index = current_index;
        
        // Update index
        update_index(&mut protocol.state, ctx);
        
        // Mint the accrued interest as new coins
        coin::mint(&mut protocol.treasury_cap, accrued_amount, ctx)
    }
    
    /// Auto-claim interest for an earning account (used in transfers)
    /// @param protocol: Mutable reference to MTokenProtocol
    /// @param account: Account to auto-claim for
    /// @param ctx: Transaction context
    /// @return: Coin with claimed interest (zero coin if no interest)
    public fun auto_claim_interest(
        protocol: &mut MTokenProtocol,
        account: address,
        ctx: &mut TxContext
    ): Coin<M_TOKEN> {
        if (is_earning(protocol, account)) {
            claim_interest(protocol, account, ctx)
        } else {
            coin::zero<M_TOKEN>(ctx)
        }
    }
    
    // ============ Sui-Native Transfer Functions ============
    
    /// Transfer M_TOKEN with auto-claim for earning accounts
    /// @param protocol: Mutable reference to MTokenProtocol
    /// @param from_coin: Coin to transfer from
    /// @param amount: Amount to transfer (in smallest units)
    /// @param recipient: Recipient address
    /// @param ctx: Transaction context
    /// @return: (remaining_coin, claimed_interest_sender, claimed_interest_recipient)
    public fun transfer_with_claim(
        protocol: &mut MTokenProtocol,
        mut from_coin: Coin<M_TOKEN>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ): (Coin<M_TOKEN>, Coin<M_TOKEN>, Coin<M_TOKEN>) {
        let sender = ctx.sender();
        
        // Auto-claim for sender if earning
        let sender_claimed = auto_claim_interest(protocol, sender, ctx);
        
        // Auto-claim for recipient if earning
        let recipient_claimed = auto_claim_interest(protocol, recipient, ctx);
        
        // Perform the actual coin transfer
        let transfer_coin = coin::split(&mut from_coin, amount, ctx);
        transfer::public_transfer(transfer_coin, recipient);
        
        // Emit transfer event for internal tracking
        sui::event::emit(TransferEvent { 
            from: sender, 
            to: recipient, 
            amount: (amount as u256)
        });
        
        (from_coin, sender_claimed, recipient_claimed)
    }
    
    /// Simple transfer function that handles auto-claim internally
    /// @param protocol: Mutable reference to MTokenProtocol
    /// @param from_coin: Coin to transfer from
    /// @param amount: Amount to transfer
    /// @param recipient: Recipient address
    /// @param ctx: Transaction context
    /// @return: remaining coin after transfer (with any claimed interest merged)
    public fun transfer(
        protocol: &mut MTokenProtocol,
        from_coin: Coin<M_TOKEN>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ): Coin<M_TOKEN> {
        let (remaining_coin, sender_claimed, recipient_claimed) = transfer_with_claim(
            protocol, from_coin, amount, recipient, ctx
        );
        
        // Merge sender's claimed interest with remaining coin
        let mut final_coin = remaining_coin;
        coin::join(&mut final_coin, sender_claimed);
        
        // Transfer recipient's claimed interest directly to them
        if (coin::value(&recipient_claimed) > 0) {
            transfer::public_transfer(recipient_claimed, recipient);
        } else {
            coin::destroy_zero(recipient_claimed);
        };
        
        final_coin
    }
    
    /// Public claim function for users to manually claim their interest
    /// @param protocol: Mutable reference to MTokenProtocol
    /// @param ctx: Transaction context
    /// @return: Coin with claimed interest
    public fun claim(
        protocol: &mut MTokenProtocol,
        ctx: &mut TxContext
    ): Coin<M_TOKEN> {
        claim_interest(protocol, ctx.sender(), ctx)
    }
    
    // ============ Transfer Helper Functions ============
    
    /// Add earning amount to an account by increasing its principal
    /// @param protocol: Mutable reference to MTokenProtocol
    /// @param account: Account to add principal to
    /// @param principal_amount: Principal amount to add
    public fun add_earning_amount(protocol: &mut MTokenProtocol, account: address, principal_amount: u128) {
        if (principal_amount == 0) return;
        
        // Get or create earning state for account
        if (!table::contains(&protocol.state.earning_accounts, account)) {
            let earning_state = EarningState { 
                principal_amount: 0,
                last_claim_index: continuous_indexing::latest_index(&protocol.state.indexing)
            };
            table::add(&mut protocol.state.earning_accounts, account, earning_state);
        };
        
        let earning_state = table::borrow_mut(&mut protocol.state.earning_accounts, account);
        earning_state.principal_amount = earning_state.principal_amount + principal_amount;
        
        // Update total earning supply
        protocol.state.principal_of_total_earning_supply = 
            protocol.state.principal_of_total_earning_supply + principal_amount;
    }
    
    /// Subtract earning amount from an account by decreasing its principal
    /// @param protocol: Mutable reference to MTokenProtocol
    /// @param account: Account to subtract principal from
    /// @param principal_amount: Principal amount to subtract
    public fun subtract_earning_amount(protocol: &mut MTokenProtocol, account: address, principal_amount: u128) {
        if (principal_amount == 0) return;
        
        assert!(table::contains(&protocol.state.earning_accounts, account), EInsufficientBalance);
        
        let earning_state = table::borrow_mut(&mut protocol.state.earning_accounts, account);
        assert!(earning_state.principal_amount >= principal_amount, EInsufficientBalance);
        
        earning_state.principal_amount = earning_state.principal_amount - principal_amount;
        
        // Update total earning supply
        protocol.state.principal_of_total_earning_supply = 
            protocol.state.principal_of_total_earning_supply - principal_amount;
    }
    
    /// Add non-earning amount to the total non-earning supply
    /// @param protocol: Mutable reference to MTokenProtocol
    /// @param amount: Present amount to add to non-earning supply
    public fun add_non_earning_amount(protocol: &mut MTokenProtocol, amount: u256) {
        if (amount == 0) return;
        protocol.state.total_non_earning_supply = protocol.state.total_non_earning_supply + amount;
    }
    
    /// Subtract non-earning amount from the total non-earning supply
    /// @param protocol: Mutable reference to MTokenProtocol
    /// @param amount: Present amount to subtract from non-earning supply
    public fun subtract_non_earning_amount(protocol: &mut MTokenProtocol, amount: u256) {
        if (amount == 0) return;
        assert!(protocol.state.total_non_earning_supply >= amount, EInsufficientBalance);
        protocol.state.total_non_earning_supply = protocol.state.total_non_earning_supply - amount;
    }
    
    /// Internal transfer logic when sender and recipient have same earning status
    /// @param protocol: Mutable reference to MTokenProtocol
    /// @param sender: Sending account
    /// @param recipient: Receiving account
    /// @param amount: Amount to transfer (principal if earning, present if non-earning)
    fun transfer_in_kind(
        protocol: &mut MTokenProtocol, 
        sender: address, 
        recipient: address, 
        amount: u256
    ) {
        let is_earning = is_earning(protocol, sender);
        
        if (is_earning) {
            // Transfer principal amount between earning accounts
            let principal_amount = (amount as u128);
            subtract_earning_amount(protocol, sender, principal_amount);
            add_earning_amount(protocol, recipient, principal_amount);
        } else {
            // For non-earning accounts, we just track total supply changes
            // Individual balances are managed by Coin objects in Sui
            // This is a no-op for total supply since it's an in-kind transfer
        }
    }
    
    /// Main internal transfer function handling all transfer types
    /// @param protocol: Mutable reference to MTokenProtocol
    /// @param sender: Sending account
    /// @param recipient: Receiving account  
    /// @param amount: Present amount to transfer
    /// @param ctx: Transaction context
    public fun transfer_internal(
        protocol: &mut MTokenProtocol,
        sender: address,
        recipient: address,
        amount: u256,
        ctx: &mut TxContext
    ) {
        // Check for invalid recipient (zero address)
        assert!(recipient != @0x0, EInvalidRecipient);
        
        // Check if amount is valid
        assert!(amount > 0, EInsufficientAmount);
        
        // Emit transfer event
        sui::event::emit(TransferEvent { 
            from: sender, 
            to: recipient, 
            amount 
        });
        
        let sender_is_earning = is_earning(protocol, sender);
        let recipient_is_earning = is_earning(protocol, recipient);
        
        // Handle in-kind transfer (same earning status)
        if (sender_is_earning == recipient_is_earning) {
            if (sender_is_earning) {
                // Both earning: convert amount to principal and transfer
                let principal = get_principal_amount_rounded_up(amount, &protocol.state, ctx);
                transfer_in_kind(protocol, sender, recipient, (principal as u256));
            } else {
                // Both non-earning: handled by Coin transfer in Sui
                // No internal state updates needed
            };
            return
        };
        
        // Handle cross-type transfer (different earning status)
        if (sender_is_earning) {
            // Sender earning, recipient non-earning
            let principal = get_principal_amount_rounded_up(amount, &protocol.state, ctx);
            subtract_earning_amount(protocol, sender, principal);
            add_non_earning_amount(protocol, amount);
        } else {
            // Sender non-earning, recipient earning
            let principal = get_principal_amount_rounded_down(amount, &protocol.state, ctx);
            subtract_non_earning_amount(protocol, amount);
            add_earning_amount(protocol, recipient, principal);
        };
        
        // Update index after transfer
        update_index(&mut protocol.state, ctx);
    }
    
}
