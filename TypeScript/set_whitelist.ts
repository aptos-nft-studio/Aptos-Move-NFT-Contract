import { AptosClient, AptosAccount, HexString} from "aptos";
const NODE_URL = "https://fullnode.devnet.aptoslabs.com";
const WHITELIST = ["0xe0cdb30a0e1f46985dd326aa3b64eaca4d78d4e114a86c8b9f78953daf62e38e","0x81f7138fbc908d1984f79a7d41edc3330285d67bc7a6e03cee356f49cb221a63","0xbf8604e24ef3e91ea18bf106257a50d08eb7b4b35131fc32dcba2e4132580ca1"];
const CONTRACT_ADDRESS = '0xcadf97e3761e31907016f5f7be5007c88b3fb8300aaee04182271887bcec2f44';
const ACCOUNT_ADDRESS = '0xd448330b73b8c8e656aec5c1c389c53ac09f105b445e3262b5fc6b3ac7f27452';
const PRIVATE_KEY ='0x2660ba74cf9896b0a43e71808b914d49ae27eeef6ad43c7ff07f2adf5937d08a';
const privateKeyBytes = new HexString(PRIVATE_KEY).toUint8Array();
(async()=>{
    const aptosClient = new AptosClient(NODE_URL);
    const adminAccount = new AptosAccount(privateKeyBytes,ACCOUNT_ADDRESS);

        // Generate a transactions
        const payload = {
          type: "entry_function_payload",
          function: `${CONTRACT_ADDRESS}::minting::set_whitelist_address`,
          type_arguments: [],
          arguments: [WHITELIST],
        };
        let txInfo;
        try {

          const txHash = await aptosClient.generateTransaction(ACCOUNT_ADDRESS,payload);
          const signedTxn = await aptosClient.signTransaction(adminAccount,txHash);
          const transactionRes = await aptosClient.submitTransaction(signedTxn);
          const response = await aptosClient.waitForTransaction(transactionRes.hash);
          console.log(transactionRes)
        } catch (err) {
          txInfo = {
            success: false,
            vm_status: err.message,
          }
          console.log(err)
        }


})();