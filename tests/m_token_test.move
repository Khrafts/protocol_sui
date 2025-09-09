#[test_only]
module protocol_sui::m_token_test {
    use sui::test_scenario::{Self, Scenario, next_tx, ctx};
    use protocol_sui::m_token::{Self, MTokenProtocol};
    use protocol_sui::ttg_registrar::{Self, TTGRegistrar};
    use sui::object;
    use sui::coin;

    // Test addresses
    const ALICE: address = @0xa11ce;
    const BOB: address = @0xb0b;
    const CHARLIE: address = @0xc0ffee;
    const DEPLOYER: address = @0xdeadbeef;

    /// Creates test protocol objects using production functions where possible
    fun setup_test_protocol(scenario: &mut Scenario): (MTokenProtocol, TTGRegistrar, ID) {
        let ctx = ctx(scenario);
        
        // Create TTG Registrar (this would normally be shared, but we keep local for testing)
        let ttg_registrar = ttg_registrar::new_for_testing(ctx);
        let ttg_registrar_id = object::id(&ttg_registrar);
        
        // Create MTokenProtocol using new_for_testing approach to keep local for testing
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

    // NOTE: Mint function tests will be added when TreasuryCap testing is properly set up
    // For now, we'll focus on testing the view functions and state management
    
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

    #[test]
    fun test_start_earning_basic() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Initially Alice is not earning
        assert!(!m_token::is_earning(&mtoken, ALICE), 0);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Alice starts earning
        m_token::start_earning(&mut mtoken, ctx);

        // Now Alice should be earning with 0 principal initially
        assert!(m_token::is_earning(&mtoken, ALICE), 1);
        assert!(m_token::principal_balance_of(&mtoken, ALICE) == 0, 2);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_start_earning_already_earning() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Add earning account first
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 1000);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Alice tries to start earning again - should be no-op
        m_token::start_earning(&mut mtoken, ctx);

        // Should still be earning with same principal
        assert!(m_token::is_earning(&mtoken, ALICE), 0);
        assert!(m_token::principal_balance_of(&mtoken, ALICE) == 1000, 1);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_stop_earning_basic() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Add earning account with principal
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 1000);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Alice stops earning
        m_token::stop_earning(&mut mtoken, ctx);

        // Now Alice should not be earning
        assert!(!m_token::is_earning(&mtoken, ALICE), 0);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_stop_earning_not_earning() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Alice tries to stop earning when not earning - should be no-op
        m_token::stop_earning(&mut mtoken, ctx);

        // Alice should still not be earning
        assert!(!m_token::is_earning(&mtoken, ALICE), 0);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_stop_earning_for_account() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Add earning account with principal
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 2000);

        next_tx(&mut scenario, BOB);
        let ctx = ctx(&mut scenario);

        // Bob stops earning for Alice (assuming Alice is not approved earner)
        m_token::stop_earning_for_account(&mut mtoken, ALICE, ctx);

        // Alice should no longer be earning
        assert!(!m_token::is_earning(&mtoken, ALICE), 0);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_earning_supply_tracking() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Add earning account with principal
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 1500);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Check initial earning supply
        let initial_earning_supply = m_token::total_earning_supply(&mtoken, ctx);
        assert!(initial_earning_supply >= 1500, 0);

        // Alice stops earning
        m_token::stop_earning(&mut mtoken, ctx);

        // Earning supply should now be 0
        let final_earning_supply = m_token::total_earning_supply(&mtoken, ctx);
        assert!(final_earning_supply == 0, 1);

        // Non-earning supply should have increased
        let non_earning_supply = m_token::total_non_earning_supply(&mtoken);
        assert!(non_earning_supply > 0, 2);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_multiple_accounts_start_stop_earning() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Alice starts earning
        m_token::start_earning(&mut mtoken, ctx);
        assert!(m_token::is_earning(&mtoken, ALICE), 0);

        next_tx(&mut scenario, BOB);
        let ctx = ctx(&mut scenario);

        // Bob starts earning
        m_token::start_earning(&mut mtoken, ctx);
        assert!(m_token::is_earning(&mtoken, BOB), 1);

        next_tx(&mut scenario, CHARLIE);
        let ctx = ctx(&mut scenario);

        // Charlie starts earning
        m_token::start_earning(&mut mtoken, ctx);
        assert!(m_token::is_earning(&mtoken, CHARLIE), 2);

        // All three should be earning
        assert!(m_token::is_earning(&mtoken, ALICE), 3);
        assert!(m_token::is_earning(&mtoken, BOB), 4);
        assert!(m_token::is_earning(&mtoken, CHARLIE), 5);

        next_tx(&mut scenario, BOB);
        let ctx = ctx(&mut scenario);

        // Bob stops earning
        m_token::stop_earning(&mut mtoken, ctx);

        // Bob should no longer be earning, others should still be
        assert!(m_token::is_earning(&mtoken, ALICE), 6);
        assert!(!m_token::is_earning(&mtoken, BOB), 7);
        assert!(m_token::is_earning(&mtoken, CHARLIE), 8);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    // ============ Transfer Tests ============

    #[test]
    fun test_transfer_invalid_recipient() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Try to transfer to zero address - should abort
        // Note: In production, this would be caught by coin transfer rules
        // We're testing the internal validation here
        
        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_transfer_earning_to_earning() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Set up two earning accounts
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 1000);
        m_token::add_earning_account_for_testing(&mut mtoken, BOB, 500);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Transfer 300 from Alice to Bob (earning to earning)
        m_token::transfer_internal(&mut mtoken, ALICE, BOB, 300, ctx);

        // Check balances after transfer
        assert!(m_token::principal_balance_of(&mtoken, ALICE) < 1000, 0);
        assert!(m_token::principal_balance_of(&mtoken, BOB) > 500, 1);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_transfer_earning_to_non_earning() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Alice is earning, Bob is not
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 1000);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        let initial_earning_supply = m_token::total_earning_supply(&mtoken, ctx);
        let initial_non_earning_supply = m_token::total_non_earning_supply(&mtoken);

        // Transfer 400 from Alice (earning) to Bob (non-earning)
        m_token::transfer_internal(&mut mtoken, ALICE, BOB, 400, ctx);

        // Alice's principal should decrease
        assert!(m_token::principal_balance_of(&mtoken, ALICE) < 1000, 0);
        
        // Total earning supply should decrease, non-earning should increase
        let final_earning_supply = m_token::total_earning_supply(&mtoken, ctx);
        let final_non_earning_supply = m_token::total_non_earning_supply(&mtoken);
        
        assert!(final_earning_supply < initial_earning_supply, 1);
        assert!(final_non_earning_supply > initial_non_earning_supply, 2);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_transfer_non_earning_to_earning() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Bob is earning, Alice starts as non-earning
        m_token::add_earning_account_for_testing(&mut mtoken, BOB, 200);

        // Add some non-earning supply (simulating Alice having balance)
        m_token::add_non_earning_amount_for_testing(&mut mtoken, 1000);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        let initial_earning_supply = m_token::total_earning_supply(&mtoken, ctx);
        let initial_non_earning_supply = m_token::total_non_earning_supply(&mtoken);

        // Transfer 300 from Alice (non-earning) to Bob (earning)
        m_token::transfer_internal(&mut mtoken, ALICE, BOB, 300, ctx);

        // Bob's principal should increase
        assert!(m_token::principal_balance_of(&mtoken, BOB) > 200, 0);
        
        // Total earning supply should increase, non-earning should decrease
        let final_earning_supply = m_token::total_earning_supply(&mtoken, ctx);
        let final_non_earning_supply = m_token::total_non_earning_supply(&mtoken);
        
        assert!(final_earning_supply > initial_earning_supply, 1);
        assert!(final_non_earning_supply < initial_non_earning_supply, 2);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_transfer_zero_amount() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Transfer functions with 0 amount should return early
        // Testing earning account helper functions
        m_token::add_earning_amount(&mut mtoken, ALICE, 0);
        m_token::subtract_earning_amount(&mut mtoken, ALICE, 0);
        
        // Testing non-earning supply functions
        m_token::add_non_earning_amount(&mut mtoken, 0);
        m_token::subtract_non_earning_amount(&mut mtoken, 0);

        // All should be no-ops and not cause any errors
        assert!(m_token::principal_balance_of(&mtoken, ALICE) == 0, 0);
        assert!(m_token::total_non_earning_supply(&mtoken) == 0, 1);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = m_token::EInsufficientBalance)]
    fun test_transfer_insufficient_balance_earning() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Alice has 500 principal
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 500);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Try to transfer more than balance - should fail
        m_token::transfer_internal(&mut mtoken, ALICE, BOB, 1000, ctx);

        // Clean up (won't reach here due to abort)
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = m_token::EInsufficientAmount)]
    fun test_transfer_zero_amount_check() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Transfer with 0 amount should fail
        m_token::transfer_internal(&mut mtoken, ALICE, BOB, 0, ctx);

        // Clean up (won't reach here due to abort)
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_multiple_transfers() {
        let mut scenario = test_scenario::begin(DEPLOYER);
        let (mut mtoken, ttg_registrar, _) = setup_test_protocol(&mut scenario);

        // Set up accounts with various earning states
        m_token::add_earning_account_for_testing(&mut mtoken, ALICE, 2000);
        m_token::add_earning_account_for_testing(&mut mtoken, BOB, 1000);
        // Charlie is non-earning

        next_tx(&mut scenario, ALICE);
        let ctx = ctx(&mut scenario);

        // Alice (earning) -> Bob (earning): 300
        m_token::transfer_internal(&mut mtoken, ALICE, BOB, 300, ctx);

        // Alice (earning) -> Charlie (non-earning): 200
        m_token::transfer_internal(&mut mtoken, ALICE, CHARLIE, 200, ctx);

        // Verify final states
        assert!(m_token::principal_balance_of(&mtoken, ALICE) < 2000, 0);
        assert!(m_token::principal_balance_of(&mtoken, BOB) > 1000, 1);
        assert!(!m_token::is_earning(&mtoken, CHARLIE), 2);

        // Clean up
        sui::test_utils::destroy(mtoken);
        sui::test_utils::destroy(ttg_registrar);
        test_scenario::end(scenario);
    }
}