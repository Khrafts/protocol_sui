#[test_only]
module protocol_sui::m_token_test {
    use sui::test_scenario::{Self, Scenario, next_tx, ctx};
    use protocol_sui::m_token::{Self, MToken};
    use protocol_sui::ttg_registrar::{Self, TTGRegistrar};
    use sui::object;

    // Test addresses
    const ALICE: address = @0xa11ce;
    const BOB: address = @0xb0b;
    const CHARLIE: address = @0xc0ffee;
    const DEPLOYER: address = @0xdeadbeef;

    /// Creates test protocol objects using production functions where possible
    fun setup_test_protocol(scenario: &mut Scenario): (MToken, TTGRegistrar, ID) {
        let ctx = ctx(scenario);
        
        // Create TTG Registrar (this would normally be shared, but we keep local for testing)
        let ttg_registrar = ttg_registrar::new_for_testing(ctx);
        let ttg_registrar_id = object::id(&ttg_registrar);
        
        // Create MToken using new_for_testing approach to keep local for testing
        let mtoken = m_token::new_for_testing(ttg_registrar_id, ctx);

        (mtoken, ttg_registrar, ttg_registrar_id)
    }

    #[test]
    fun test_principal_balance_of_non_earning() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Test non-earning account - should return 0
        let principal = m_token::principal_balance_of(&mtoken, ALICE);
        assert!(principal == 0, 0);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_principal_balance_of_earning() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Add earning account with principal 1000
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 1000);

        let principal = m_token::principal_balance_of(&mtoken, ALICE);
        assert!(principal == 1000, 0);

        // Test different account - should be 0
        let bob_principal = m_token::principal_balance_of(&mtoken, BOB);
        assert!(bob_principal == 0, 1);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_is_earning() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Initially no accounts are earning
        assert!(!m_token::is_earning(&mtoken, ALICE), 0);
        assert!(!m_token::is_earning(&mtoken, BOB), 1);

        // Set Alice as earning
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 500);

        // Now Alice should be earning, Bob still not
        assert!(m_token::is_earning(&mtoken, ALICE), 2);
        assert!(!m_token::is_earning(&mtoken, BOB), 3);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_total_non_earning_supply() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Initially should be 0 (no tokens minted yet)
        let supply = m_token::total_non_earning_supply(&mtoken);
        assert!(supply == 0, 0);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_total_earning_supply_zero() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // With no earning principal, should return 0
        let supply = m_token::total_earning_supply(&mtoken, ctx);
        assert!(supply == 0, 0);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_total_earning_supply_with_principal() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Add earning account with principal 1000
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 1000);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Should return present value based on current index
        let supply = m_token::total_earning_supply(&mtoken, ctx);
        
        // Due to continuous indexing, supply should be >= principal amount
        assert!(supply >= 1000, 0);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_total_supply_only_earning() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Add earning accounts
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 2000);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        let total = m_token::total_supply(&mtoken, ctx);
        
        // Should be >= principal amount due to indexing
        assert!(total >= 2000, 0);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_total_supply_mixed() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Add earning accounts 
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 500);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        let total = m_token::total_supply(&mtoken, ctx);
        let non_earning = m_token::total_non_earning_supply(&mtoken);
        let earning = m_token::total_earning_supply(&mtoken, ctx);

        // Total should equal non-earning + earning
        assert!(total == non_earning + earning, 0);
        
        // Should be at least the principal amount (500)
        assert!(total >= 500, 1);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_ttg_registrar_id() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        let stored_id = m_token::ttg_registrar_id(&mtoken);
        let actual_id = sui::object::id(&ttg_registrar);

        assert!(stored_id == actual_id, 0);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_multiple_earning_accounts() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Set multiple earning accounts
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 1000);
        m_token::add_earning_account_for_testing(&mut mtoken, BOB, 2000);
        m_token::add_earning_account_for_testing(&mut mtoken, CHARLIE, 1500);

        // Test all accounts are earning
        assert!(m_token::is_earning(&mtoken, ALICE), 0);
        assert!(m_token::is_earning(&mtoken, BOB), 1);
        assert!(m_token::is_earning(&mtoken, CHARLIE), 2);
        
        // Test their principal balances
        assert!(m_token::principal_balance_of(&mtoken, ALICE) == 1000, 3);
        assert!(m_token::principal_balance_of(&mtoken, BOB) == 2000, 4);
        assert!(m_token::principal_balance_of(&mtoken, CHARLIE) == 1500, 5);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Total earning supply should reflect all principals
        let earning_supply = m_token::total_earning_supply(&mtoken, ctx);
        assert!(earning_supply >= 4500, 6); // 1000 + 2000 + 1500

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }
}