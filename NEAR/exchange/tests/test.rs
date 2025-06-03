pub mod common;

use near_sdk::NearToken;
use serde_json::json;

use common::{init_accounts, init_contract, ONE_YOCTO, TOKEN_ID};

#[tokio::test]
async fn test_mint() -> anyhow::Result<()> {
    let sandbox = near_workspaces::sandbox().await?;
    let root = sandbox.root_account()?;
    let (alice, _, _, _) = init_accounts(&root).await?;
    let contract = init_contract(&sandbox).await?;

    let res = contract
        .call("nft_mint")
        .args_json(json!({"token_id": TOKEN_ID, "token_owner_id": alice.id()}))
        .max_gas()
        .deposit(NearToken::from_millinear(7))
        .transact()
        .await?;
    assert!(res.is_success());

    // println!("nft_mint outcome: {:#?}", res);

    // let outcome = alice
    //     .call(contract.id(), "set_greeting")
    //     .args_json(json!({"greeting": "Hello World!"}))
    //     .transact()
    //     .await?;
    // assert!(outcome.is_success());

    // let user_message_outcome = contract.view("get_greeting").args_json(json!({})).await?;
    // assert_eq!(user_message_outcome.json::<String>()?, "Hello World!");

    Ok(())
}


