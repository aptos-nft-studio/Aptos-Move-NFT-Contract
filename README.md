# Aptos NFT Studio - Open Source Aptos NFT Move Contract

This is a tutorial for deploying a NFT collection on Aptos Devnet based on the [Aptos Token standard](https://aptos.dev/standards/aptos-token).
For the purpose of this tutorial, we will use Aptos Devnet. You can setup profiles to publish to Aptos Mainnet when ready to do so.

This repo contains the Move contract to deploy the resource.
The Dapp for frontend minting is available at this repo [Aptos NFT Dapp](https://github.com/aptos-nft-studio/Aptos-NFT-Dapp).

Video Tutorial: [https://www.youtube.com/watch?v=h1HUgilNuSE](https://www.youtube.com/watch?v=h1HUgilNuSE)

NFT Sample JSON Files: [https://github.com/aptos-nft-studio/NFT-Sample-JSON-Files](https://github.com/aptos-nft-studio/NFT-Sample-JSON-Files)

Aptos NFT Dapp: [https://github.com/aptos-nft-studio/Aptos-NFT-Dapp](https://github.com/aptos-nft-studio/Aptos-NFT-Dapp)

Aptos Move NFT Contract: [https://github.com/aptos-nft-studio/Aptos-Move-NFT-Contract](https://github.com/aptos-nft-studio/Aptos-Move-NFT-Contract)

### Pre-requisites

Step 1) 

Clone this repo.

Step 2) 

Install Aptos CLI. Refer to instructions from [Aptos website](https://aptos.dev/tools/aptos-cli).

### Create profiles and fund accounts

Step 1)

Open Terminal inside this project folder and run these below command to create profiles. The accounts are created to Devnet by dafault.

Create source account.
```bash
aptos init
```

Create admin-account.
```bash
aptos init --profile admin-account
```

Create nft-receiver.
```bash
aptos init --profile nft-receiver
```

Step 2)

Fund the accounts from faucet (only valid for Devnet and Testnet).

Fund source account. Repeat 2-3 times as publishing a module costs more gas.
```bash
aptos account fund-with-faucet --account default
```

Fund admin-account.
```bash
aptos account fund-with-faucet --account admin-account
```

Create nft-receiver
```bash
aptos account fund-with-faucet --account nft-receiver
```

Step 3)

After creating the Aptos profiles, a folder .aptos is created with the file **config.yaml** inside. Open this file.

### Update source code

Step 1)

From config.yaml, copy account address of default profile and then open move.toml file. In the source_addr put your account address make sure to add 0x in the front of address so address will be like this **source_addr = "0x19ce4969ac99e5d01f0be1413a8af3abc3143945372366765ef5e7eb25d1004e"**

Step 2)

From config.yaml, copy account address of admin-account and then open move.toml file. In the admin_addr put your account address make sure to add 0x in the front of address so address will be like this **admin_addr = "0xe17365770306373bb547e2204b556edd55debd01141b4935b9e4f092e3195cb0"**

Step 3)

Change the NFT collection settings in sources/minting.move
* Line 77. Replace ``` hardcoded_pk ``` with your admin-account public key (from config.yaml). 0x not required in front of the address.
* Line 82. Set the name of your NFT collection ``` collection_name ``` 
* Line 83. Set the description of your NFT collection ``` description ```
* Line 84. Set the meta description of your NFT collection ``` collection_uri ``` (based on (EIP-721)[https://eips.ethereum.org/EIPS/eip-721])
* Line 85. Set the name of your NFT token ``` token_name ``` 
* Line 82 to 94. Set the name of your NFT collection ``` token_uri ``` (create admin-account)
* Line 83. Set the description of your NFT collection ``` token_uri_filetype ``` (create nft-receiver account)
* Line 84. Set the Unix timestamp of minting deadline ``` expiration_timestamp ``` (create nft-receiver account)
* Line 85. Set the public price of minting 1 NFT ``` public_price ``` (create nft-receiver account)
* Line 82 to 94. Set the presale price of minting 1 NFT ``` presale_price ``` (create admin-account)
* Line 83. Set the description of your NFT collection ``` whitelist_addr ``` (create nft-receiver account)
* Line 84. Set the description of your NFT collection ``` royalty_points_denominator ``` (create nft-receiver account)
* Line 85. Set the description of your NFT collection ``` royalty_points_numerator ``` (create nft-receiver account)

### Deploy NFT collection smart contract

Step 1)

In the terminal run this command to create NFT resource account with default account. Use a different seed if you encounter error creating a new resource.

```bash 
aptos move create-resource-account-and-publish-package --seed 12343 --address-name mint_nft --profile default 
```

Step 2)

Copy the resource address. You can verify that that the resource account exists by searching it in the [Aptos Explorer](https://explorer.aptoslabs.com/). The resource address can also be found in ``` build/AptosNFTStudio/BuildInfo.yaml ``` - ``` mint_nft ```. 


## NFT Collection Contract Functions

Below are functions available with this NFT collection smart contract.
You can always check the transactions after each function in the (Aptos Explorer)[https://explorer.aptoslabs.com]. 
Select devnet in Aptos Explorer and search for your resource address, default address, admin-account address, nft-receiver address. Explore details of the transactions.
In the example function calls, replace 6ffdfeb66e0d58fd5a04d7f64b685f722c0971a355697cf559e252ab733d695c with your resource address.

**Partner Address**
If you need to share the profit with a partner, you can set a partner account address. 
```bash 
aptos move run --function-id cadf97e3761e31907016f5f7be5007c88b3fb8300aaee04182271887bcec2f44::minting::set_partner_account_address --args address:'0xb1adabcc0061ccc34b8830716db60bfb9700f864a689b0df469dc8a25ddc5142' --profile admin-account
```

**Partner Profit Share Percentage**
If you need to share the profit with a partner, it will be important to set this value. The denominator in the contract is 10000. So if you set partner_numerator to 200, it means partner will get 2% share (200/10000) of the mint fee.
```bash 
aptos move run --function-id cadf97e3761e31907016f5f7be5007c88b3fb8300aaee04182271887bcec2f44::minting::set_partner_numerator --args u64:200 --profile admin-account
```

**Presale Price**
Use admin-account to set presale price. 
```bash 
aptos move run --function-id 6ffdfeb66e0d58fd5a04d7f64b685f722c0971a355697cf559e252ab733d695c::minting::set_presale_status --args u64:10000000 --profile admin-account
```

**Public Sale Status**
Use admin-account to set presale status to either true or false. True will allow minting at the presale price. 
```bash 
aptos move run --function-id 6ffdfeb66e0d58fd5a04d7f64b685f722c0971a355697cf559e252ab733d695c::minting::set_publicsale_status --args bool:false --profile admin-account 
```

**Public Sale Price**
Use admin-account to set presale price. 
```bash 
aptos move run --function-id 6ffdfeb66e0d58fd5a04d7f64b685f722c0971a355697cf559e252ab733d695c::minting::set_public_price --args u64:12000000 --profile admin-account
```

**Mint NFT**
This will use the nft-receiver profile to mint a NFT. The final u64 is for setting how many NFTs to mint. 
```bash 
aptos move run --function-id 01e5961e571de5dff17c1a212c7ec0759d75161524d1b4755f173ed92d65cf66::minting::mint_nft --profile nft-receiver --args u64:3
```


**Change Admin Account Public Key**
This will set the public key of admin account.
```bash 
aptos move run --function-id 6ffdfeb66e0d58fd5a04d7f64b685f722c0971a355697cf559e252ab733d695c::minting::set_public_key --profile admin-account --args hex:[admin account public key]
```
Example:
```bash 
aptos move run --function-id 6ffdfeb66e0d58fd5a04d7f64b685f722c0971a355697cf559e252ab733d695c::minting::set_public_key --profile admin-account --args hex:E563FA6BC769ACD4EA99F7206156F1EACE2129DB56AEEC00D8E5DE992ADC1495
```

**Change Timestamp**
This will change the Unix timestamp for end of minting. Use this (Unix timestamp website)[https://www.unixtimestamp.com/] to convert normal date time to Unix timestamp.
```bash 
aptos move run --function-id 01e5961e571de5dff17c1a212c7ec0759d75161524d1b4755f173ed92d65cf66::minting::set_timestamp --args u64:1719873624 --profile admin-account
```

**Set Max Supply**
This will change the collection max supply. 
```bash 
aptos move run --function-id 6ffdfeb66e0d58fd5a04d7f64b685f722c0971a355697cf559e252ab733d695c::minting::set_max_supply --args u64:10 --profile admin-account
```

## How to set Whitelist addresses 

**Set Whitelist Only**
Toggle minting to be for whitelisted address only. Change the bool to true or false.
```bash 
aptos move run --function-id 6ffdfeb66e0d58fd5a04d7f64b685f722c0971a355697cf559e252ab733d695c::minting::set_whitelist_only --args bool:true --profile admin-account
```

To set whitelist, go to TypeScript folder ``` cd TypeScript```.
Install dependencies by using ``` npm i ```. 
Change the values in ``` TypeScript/set_whiteList.ts ``` file. 
* NODE_URL - this is the node url for devnet, testnet or mainnet. (Reference)[https://aptos.dev/nodes/networks/]
* CONTRACT_ADDRESS - this is the resource address.
* ACCOUNT_ADDRESS - this is the admin account address (with 0x added in front).
* PRIVATE_KEY - this is the admin account private key.
* WHITELIST - add one or more account addresses (with 0x added in front) to whitelist, with comma separator.
e.g.
``` const WHITELIST = ["0xe0cdb30a0e1f46985dd326aa3b64eaca4d78d4e114a86c8b9f78953daf62e38e","0x81f7138fbc908d1984f79a7d41edc3330285d67bc7a6e03cee356f49cb221a63","0xbf8604e24ef3e91ea18bf106257a50d08eb7b4b35131fc32dcba2e4132580ca1"]; ```
Run the typescript file type to update the whitelisted addresses ``` npx ts-node set_whitelist.ts ```. 

To check whitelist address run this command. Replace [address] with the account address you are checking for. This will return error 0x50006 if not found in white list.
```bash 
aptos move run --function-id 6ffdfeb66e0d58fd5a04d7f64b685f722c0971a355697cf559e252ab733d695c::minting::check_whitelist_address --args address:[address] --profile admin-account 
```
Example:
```bash 
aptos move run --function-id 6ffdfeb66e0d58fd5a04d7f64b685f722c0971a355697cf559e252ab733d695c::minting::check_whitelist_address --args address:0xe0cdb30a0e1f46985dd326aa3b64eaca4d78d4e114a86c8b9f78953daf62e38e --profile admin-account
```
