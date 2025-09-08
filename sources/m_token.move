module protocol_sui::m_token {
    use sui::table::{Self, Table};
    use sui::event;
    use sui::coin::{Self, Coin, CoinMetadata, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::TxContext;
    use std::option;
    use protocol_sui::continuous_indexing::{Self, ContinuousIndexing};
    use protocol_sui::continuous_indexing_math;
    use protocol_sui::ttg_registrar::{Self, TTGRegistrar};
    use protocol_sui::ttg_registrar_reader;
    use protocol_sui::uint_math;

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
    
    /// MToken balance struct
    /// Represents the balance state for an account
    public struct MBalance has store {
        /// True if the account is earning, false otherwise
        is_earning: bool,
        /// Balance (for non-earning) or balance principal (for earning)
        /// Using u256 to accommodate both uint240 (non-earning) and uint112 (earning principal)
        raw_balance: u256
    }
    
    /// Main MToken object - shared object pattern (no minting capabilities)
    public struct MToken has key {
        id: UID,
        
        /// Reference to the TTG Registrar (stored as ID for validation)
        ttg_registrar_id: ID,
        
        /// Total supply of non-earning M tokens (uint240 → u256)
        total_non_earning_supply: u256,
        
        /// Principal of total earning supply (uint112 → u128)
        principal_of_total_earning_supply: u128,
        
        /// Continuous indexing state (embedded instead of inherited)
        indexing: ContinuousIndexing,

        /// Mapping of account addresses to their balances
        balances: Table<address, MBalance>
    }
    
    /// The coin type for M token
    public struct M has drop {}
    
    /// One-time witness for module initialization
    public struct M_TOKEN has drop {}
    

    // ============ Initialization ============
    
    /// Create MToken and TreasuryCap - called by deployment script
    /// @param ttg_registrar: Reference to TTG Registrar shared object  
    /// @param minter_gateway_recipient: Address that will receive the TreasuryCap
    /// @param ctx: Transaction context
    /// Returns: TreasuryCap<M> - goes to MinterGateway
    public fun create_mtoken_and_capabilities(
        ttg_registrar: &TTGRegistrar,
        minter_gateway_recipient: address,
        ctx: &mut TxContext
    ): TreasuryCap<M> {
        // Create the M coin
        let (treasury_cap, metadata) = coin::create_currency(
            M {},  // Create witness for M coin
            DECIMALS,
            SYMBOL,
            NAME,
            b"M token for the M^0 protocol",  // Description
            option::none(),  // No icon URL
            ctx
        );
        
        // Create the MToken shared object
        let mtoken = MToken {
            id: object::new(ctx),
            ttg_registrar_id: object::id(ttg_registrar),
            total_non_earning_supply: 0,
            principal_of_total_earning_supply: 0,
            indexing: continuous_indexing::new(ctx),
            balances: table::new(ctx)
        };
        
        // Share the MToken object
        transfer::share_object(mtoken);
        
        // Freeze metadata to make it immutable and discoverable
        transfer::public_freeze_object(metadata);
        
        // Return TreasuryCap - caller will send it to MinterGateway
        treasury_cap
    }

    // ============ Test-Only Functions ============
    
    #[test_only]
    public fun initialize(_ctx: &mut TxContext) {
        // Placeholder - will be implemented with actual MToken functionality
        abort 0
    }
    
    #[test_only]
    public fun set_total_earning_supply(_mtoken: &mut MToken, _amount: u256) {
        // Placeholder - will be implemented with actual MToken functionality
        abort 0
    }
    
    #[test_only]
    public fun initialize_for_testing(
        _ttg_registrar: &TTGRegistrar,
        _minter_gateway_id: ID,
        _ctx: &mut TxContext
    ) {
        // Placeholder - will be implemented with actual MToken functionality
        abort 0
    }
    
    // ============ Capability-Gated Functions ============
    
    /// Mint M tokens - only callable by MinterGateway with TreasuryCap
    /// @param mtoken: The MToken shared object
    /// @param treasury_cap: TreasuryCap for minting coins and access control
    /// @param account: Address to mint tokens to
    /// @param amount: Amount to mint
    public fun mint(
        mtoken: &mut MToken,
        treasury_cap: &mut TreasuryCap<M>,
        account: address,
        amount: u256
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
        mtoken: &mut MToken,
        treasury_cap: &mut TreasuryCap<M>,
        account: address,
        amount: u256
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
    
    // ============ View Functions (placeholders) ============
    
    /// Get the total earning supply
    public fun total_earning_supply(_mtoken: &MToken): u256 {
        // Placeholder - will calculate from principal using current index
        0
    }
    
    /// Get the TTG Registrar ID
    public fun ttg_registrar_id(mtoken: &MToken): ID {
        mtoken.ttg_registrar_id
    }
    
}
