use near_sdk::{AccountId, NearToken};
use near_workspaces::{Account, Contract, DevNetwork, Worker};

const INITIAL_BALANCE: NearToken = NearToken::from_near(30);
pub const ONE_YOCTO: NearToken = NearToken::from_yoctonear(1);
pub const TOKEN_ID: &str = "id-0";

pub async fn init_accounts(root: &Account) -> anyhow::Result<(Account, Account, Account, Account)> {
    // create accounts
    let alice = root
        .create_subaccount("alice")
        .initial_balance(INITIAL_BALANCE)
        .transact()
        .await?
        .into_result()?;
    let bob = root
        .create_subaccount("bob")
        .initial_balance(INITIAL_BALANCE)
        .transact()
        .await?
        .into_result()?;
    let charlie = root
        .create_subaccount("charlie")
        .initial_balance(INITIAL_BALANCE)
        .transact()
        .await?
        .into_result()?;
    let dave = root
        .create_subaccount("dave")
        .initial_balance(INITIAL_BALANCE)
        .transact()
        .await?
        .into_result()?;

    return Ok((alice, bob, charlie, dave));
}

pub async fn init_contract(
    sandbox: &Worker<impl DevNetwork>,
) -> anyhow::Result<Contract> {
    let contract_wasm = near_workspaces::compile_project("./").await?;
    let contract = sandbox.dev_deploy(&contract_wasm).await?;

    let res = contract
        .call("init")
        .max_gas()
        .transact()
        .await?;
    assert!(res.is_success());

    return Ok(contract);
}

pub async fn register_user(contract: &Contract, account_id: &AccountId) -> anyhow::Result<()> {
    let res = contract
        .call("storage_deposit")
        .args_json((account_id, Option::<bool>::None))
        .max_gas()
        .deposit(near_sdk::env::storage_byte_cost().saturating_mul(125))
        .transact()
        .await?;
    assert!(res.is_success());

    Ok(())
}