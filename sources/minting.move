module mint_nft::minting {
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::aptos_account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;
    use aptos_std::ed25519;
    use aptos_token::token::{Self, TokenDataId};
    use aptos_framework::resource_account;
    #[test_only]
    use aptos_framework::account::create_account_for_test;
    use aptos_std::ed25519::ValidatedPublicKey;

    // This struct stores the token receiver's address and token_data_id in the event of token minting
    struct TokenMintingEvent has drop, store {
        token_receiver_address: address,
        token_data_id: TokenDataId,
    }

    // This struct stores an NFT collection's relevant information
    struct ModuleData has key {
        public_key: ed25519::ValidatedPublicKey,
        signer_cap: account::SignerCapability,
        // token_data_id: TokenDataId,
        expiration_timestamp: u64,
        minting_enabled: bool,
        public_price:u64,
        presale_price:u64,
        current_supply:u64,
        maximum_supply:u64,
        publicsale_status:bool,
        presale_status:bool,
        token_minting_events: EventHandle<TokenMintingEvent>,
        whitelist_only:bool,
        whitelist_addr:vector<address>,
        royalty_account_address: address,
        partner_account_address: address,
        resource_account_address:address,
        royalty_points_denominator:u64,
        partner_numerator:u64,
        royalty_points_numerator:u64,
        collection_name:String,
        description:String,
        token_name:String,
        token_uri:String,
        token_uri_filetype:String,
    }

    // This struct stores the challenge message that proves that the resource signer wants to mint this token
    // to the receiver. This struct will need to be signed by the resource signer to pass the verification.
    struct MintProofChallenge has drop {
        receiver_account_sequence_number: u64,
        receiver_account_address: address,
        token_data_id: TokenDataId,
    }

    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;
    /// The collection minting is expired
    const ECOLLECTION_EXPIRED: u64 = 2;
    /// The collection minting is disabled
    const EMINTING_DISABLED: u64 = 3;
    /// Specified public key is not the same as the admin's public key
    const EWRONG_PUBLIC_KEY: u64 = 4;
    /// Specified scheme required to proceed with the smart contract operation - can only be ED25519_SCHEME(0) OR MULTI_ED25519_SCHEME(1)
    const EINVALID_SCHEME: u64 = 5;
    /// Specified proof of knowledge required to prove ownership of a public key is invalid
    const EINVALID_PROOF_OF_KNOWLEDGE: u64 = 7;
    /// Specified address is not include in the whitelist address
    const NOT_FOUND: u64 = 6;

    /// Initialize this module: create a resource account, a collection, and a token data id
    fun init_module(resource_account: &signer) {
        // NOTE: This is just an example public key; please replace this with your desired admin PK.
        let hardcoded_pk = x"7ab923f5727b54ebdfab82688994a1a2caa99b2b8c7f70d9004b266f3e235b6a";
        init_module_with_admin_public_key(resource_account, hardcoded_pk);
    }

    fun init_module_with_admin_public_key(resource_account: &signer, pk_bytes: vector<u8>) {
        let collection_name = string::utf8(b"Aptos NFT Studio Launch 1");
        let description = string::utf8(b"This is a devnet NFT collection.");
        let collection_uri = string::utf8(b"https://sapphire-satisfied-ferret-847.mypinata.cloud/ipfs/QmeEdhFzQNEQ3NMJj2F8rrrKGHn25ZN5LeMY87wRYwhUaU");
        let token_name = string::utf8(b"ANFT #");
        let token_uri = string::utf8(b"https://sapphire-satisfied-ferret-847.mypinata.cloud/ipfs/QmRemeRtyiLyBXfCVMU3YZgDeKppD9CGREyGGk1mDMJB6y/");
        let token_uri_filetype = string::utf8(b".json");
        let expiration_timestamp = 1916815947;
        let public_price = 1100000;
        let presale_price = 1000000;
        let whitelist_addr = vector::empty<address>();
        let whitelist_only =false;
       let royalty_points_denominator = 10000;
       let royalty_points_numerator = 800;

        // change source_addr to the actual account that created the resource account
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_account, @source_addr);
        let resource_signer = account::create_signer_with_capability(&resource_signer_cap);
        let maximum_supply = 100;
        let current_supply = 0;
        let mutate_setting = vector<bool>[ false, false, false ];
        let resource_account_address = signer::address_of(&resource_signer);
        let royalty_account_address = @admin_addr; 
        let partner_account_address = @aptosnftstudio_addr; 
        let partner_numerator = 100; //100 is 1% based on 100/10000 (royalty_points_denominator)
        // create the nft collection - https://aptos.dev/concepts/coin-and-token/aptos-token/#collectiondata
        token::create_collection(&resource_signer, collection_name, description, collection_uri, maximum_supply, mutate_setting);

        let public_key = std::option::extract(&mut ed25519::new_validated_public_key_from_bytes(pk_bytes));

        move_to(resource_account, ModuleData {
            public_key,
            signer_cap: resource_signer_cap,
            expiration_timestamp,
            maximum_supply,
            current_supply,
            royalty_account_address,
            resource_account_address,
            partner_account_address,
            partner_numerator,
            public_price,
            presale_price,
            royalty_points_denominator,
            minting_enabled: true,
            presale_status:false,
            publicsale_status:true,
            whitelist_addr,
            whitelist_only,
            token_name,
            token_uri,
            collection_name,
            description,
            token_uri_filetype,
            royalty_points_numerator,
            token_minting_events: account::new_event_handle<TokenMintingEvent>(&resource_signer),
        });
    }

     /// Set true if only whitelisted addresses can mint
    public entry fun set_whitelist_only(caller: &signer, whitelist_only: bool) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.whitelist_only = whitelist_only;
    }

    /// Set if minting is enabled for this minting contract
    public entry fun set_minting_enabled(caller: &signer, minting_enabled: bool) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.minting_enabled = minting_enabled;
    }

     /// Set presale stauts is enabled for this minting contract
    public entry fun set_presale_status(caller: &signer, presale_status: bool) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.presale_status = presale_status;
    }

    /// Set if presale_price this minting contract
    public entry fun set_presale_price(caller: &signer, presale_price: u64) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.presale_price = presale_price;
    }

     /// Set presale stauts is enabled for this minting contract
    public entry fun set_publicsale_status(caller: &signer, publicsale_status: bool) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.publicsale_status = publicsale_status;
    }

     /// Set if public_price this minting contract
    public entry fun set_public_price(caller: &signer, public_price: u64) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.public_price = public_price;
    }


    /// Set the expiration timestamp of this minting contract
    public entry fun set_timestamp(caller: &signer, expiration_timestamp: u64) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.expiration_timestamp = expiration_timestamp;
    }

    /// Set the max supply value of this minting contract
    public entry fun set_max_supply(caller: &signer, maximum_supply: u64) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.maximum_supply = maximum_supply;
    }

    /// Set the public key of this minting contract
    public entry fun set_public_key(caller: &signer, pk_bytes: vector<u8>) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.public_key = std::option::extract(&mut ed25519::new_validated_public_key_from_bytes(pk_bytes));
    }

    // White list address
     public entry fun set_whitelist_address(caller: &signer, whitelist_addr:vector<address>) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.whitelist_addr = whitelist_addr;
    }

    //check white list address
     public entry fun check_whitelist_address(_addr:address) acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        let whitelist_addresses = module_data.whitelist_addr;
        let a = vector::contains(&whitelist_addresses,&_addr);
        assert!(a == true, error::permission_denied(NOT_FOUND));
    }
         /// Set royalty_account_address
    public entry fun set_royalty_account_address(caller: &signer, _addr:address) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.royalty_account_address = _addr;
    }

     /// Set partner_account_address 
     public entry fun set_partner_account_address(caller: &signer, _addr:address) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.partner_account_address = _addr;
    }
     /// Set partner_numerator
    public entry fun set_partner_numerator(caller: &signer, _numberator:u64) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.partner_numerator = _numberator;
    }

    /// Mint an NFT to the receiver.
    /// `mint_proof_signature` should be the `MintProofChallenge` signed by the admin's private key
    /// `public_key_bytes` should be the public key of the admin
    public entry fun mint_nft(receiver: &signer, quantity: u64) acquires ModuleData {
        let receiver_addr = signer::address_of(receiver);

        // Get the collection minter and check if the collection minting is disabled or expired
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        assert!(timestamp::now_seconds() < module_data.expiration_timestamp, error::permission_denied(ECOLLECTION_EXPIRED));
        assert!(module_data.current_supply + quantity <= module_data.maximum_supply, error::permission_denied(EMINTING_DISABLED));
        assert!(module_data.minting_enabled, error::permission_denied(EMINTING_DISABLED));
        assert!(module_data.presale_status || module_data.publicsale_status, error::permission_denied(EMINTING_DISABLED));
        
        let mint_fee = if (module_data.presale_status) module_data.presale_price else module_data.public_price;
        
        // Check if receiver address is one of the whitelist addresses
        if (module_data.whitelist_only) {
            let whitelist_addresses = module_data.whitelist_addr;
            let a = vector::contains(&whitelist_addresses,&receiver_addr);
            assert!(a == true, error::permission_denied(NOT_FOUND));
        };

        //Transfer tokens
        if (module_data.partner_account_address == @admin_addr) { 
            aptos_account::transfer(receiver, @admin_addr, mint_fee * quantity);
        } else {
            let _denominator:u64 = module_data.royalty_points_denominator;
            let _partner_numerator:u64 = module_data.partner_numerator;
            let _totalfee: u64 = mint_fee * quantity;

            let _partnersplit: u64 = (copy _totalfee * copy _partner_numerator) / copy _denominator;
            aptos_account::transfer(receiver, module_data.partner_account_address, _partnersplit);

            let _adminsplit: u64 = copy _totalfee - copy _partnersplit;
            aptos_account::transfer(receiver, @admin_addr, _adminsplit);
        };
            let startingid = module_data.current_supply;
            //module_data.current_supply = module_data.current_supply + quantity;

            let i: u64 = 1;
            while (i <= quantity) {

                // Change current supply into string type
                let _token_name = module_data.token_name;
                let _token_uri = module_data.token_uri;
                
                let supply = to_string(startingid + i);
                string::append(&mut _token_name, supply);
                string::append(&mut _token_uri, supply);
                string::append(&mut _token_uri, module_data.token_uri_filetype);

                // Create resource signer with signer cap
                let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);

                // Create a token data id to specify which token will be minted
                let token_data_id = token::create_tokendata(
                    &resource_signer,
                    module_data.collection_name,
                    _token_name,
                    module_data.description,
                    1,
                    _token_uri,
                    module_data.royalty_account_address,
                    module_data.royalty_points_denominator,
                    module_data.royalty_points_numerator,
                    // We don't allow any mutation to the token
                    token::create_token_mutability_config(
                        &vector<bool>[ true, false, true, true, true ]
                    ),
                    vector::empty<String>(),
                    vector::empty<vector<u8>>(),
                    vector::empty<String>(),
                );

                // Mint token to the receiver
                let token_id = token::mint_token(&resource_signer, token_data_id, 1);
                token::direct_transfer(&resource_signer, receiver, token_id, 1);

                // Emit TokenMintingEvent for each minted token
                event::emit_event<TokenMintingEvent>(
                    &mut module_data.token_minting_events,
                    TokenMintingEvent {
                        token_receiver_address: receiver_addr,
                        token_data_id: token_data_id,
                    }
                );
                i = i + 1;  // Incrementing the counter
                module_data.current_supply = module_data.current_supply + 1;
            }



    }

    /// Verify that the collection token minter intends to mint the given token_data_id to the receiver
    fun verify_proof_of_knowledge(receiver_addr: address, mint_proof_signature: vector<u8>, token_data_id: TokenDataId, public_key: ValidatedPublicKey) {
        let sequence_number = account::get_sequence_number(receiver_addr);

        let proof_challenge = MintProofChallenge {
            receiver_account_sequence_number: sequence_number,
            receiver_account_address: receiver_addr,
            token_data_id,
        };

        let signature = ed25519::new_signature_from_bytes(mint_proof_signature);
        let unvalidated_public_key = ed25519::public_key_to_unvalidated(&public_key);
        assert!(ed25519::signature_verify_strict_t(&signature, &unvalidated_public_key, proof_challenge), error::invalid_argument(EINVALID_PROOF_OF_KNOWLEDGE));
    }

    // u64 into string
    fun to_string(value: u64): String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        string::utf8(buffer)
    }
   
}