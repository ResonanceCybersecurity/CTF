use std::{collections::HashMap, hash::Hash, ops::Deref};

// Find all our documentation at https://docs.near.org
use near_sdk::{assert_one_yocto, env, json_types::U64, log, near, require, store::LookupMap, AccountId, BorshStorageKey, NearToken, PanicOnDefault, Promise, PromiseError};
use near_contract_standards::non_fungible_token::{core::NonFungibleTokenCore, events::NftTransfer, metadata::TokenMetadata, NonFungibleToken, Token, TokenId};

use near_sdk::ext_contract;

// Validator interface, for cross-contract calls
#[ext_contract(exchange)]
trait Exchange {
    fn nft_transfer(
        &mut self,
        sender_id: AccountId,
        receiver_id: AccountId,
        token_id: TokenId,
        approval_id: Option<u64>,
        memo: Option<String>,
    );
}

#[derive(BorshStorageKey)]
#[near]
enum StorageKey {
    ArtPieces,
    Rewards,
    TokensPerOwner { account_hash: Vec<u8> },
}

// Define the contract structure
#[near(contract_state)]
#[derive(PanicOnDefault)]
pub struct Contract {
    art_pieces_account: AccountId,
    displayed_art_pieces: LookupMap<AccountId, TokenId>,
    rented_art_pieces: LookupMap<TokenId, u64>,
    rewards: LookupMap<TokenId, u64>,
    epoch: u64,
    reward_per_epoch: u128,
}

// Implement the contract structure
#[near]
impl Contract {
    #[init]
    pub fn init(art_pieces_account: AccountId) -> Self {
        Self {
            art_pieces_account,
            displayed_art_pieces: LookupMap::new(StorageKey::ArtPieces),
            rented_art_pieces: LookupMap::new(StorageKey::ArtPieces),
            rewards: LookupMap::new(StorageKey::Rewards),
            epoch: 2628000000000000, // 1 month in nanoseconds
            reward_per_epoch: 1, // 1 NEAR
        }
    }

    pub fn display_art_piece(
        &mut self,
        token_id: TokenId,
        rent: Option<bool>,
    ) -> Promise {
        self.displayed_art_pieces.insert(env::predecessor_account_id(), token_id.clone());

        if rent.is_some() {
            require!(env::account_balance() < NearToken::from_near(self.reward_per_epoch), "Not enough funds to cover 1 month of rent");
            self.rented_art_pieces.insert(token_id.clone(), env::block_timestamp());
        }

        let promise = exchange::ext(self.art_pieces_account.clone())
            .nft_transfer(
                env::predecessor_account_id(),
                env::current_account_id(),
                token_id,
                None,
                None
            );

        promise.then(
            Self::ext(env::current_account_id())
                .display_art_piece_callback(),
        )
    }

    pub fn display_art_piece_callback(
        &self,
        #[callback_result] call_result: Result<String, PromiseError>,
    ) -> bool {
        env::log_str(call_result.unwrap().as_str());
        true
    }

    pub fn collect_rewards(&mut self, token_id: TokenId) {
        let mut reward: u128 = 0;
        if let Some(rented_time_start) = self.rented_art_pieces.get(&token_id) {
            let rented_time = (env::block_timestamp() - rented_time_start) as u128;
            reward = rented_time / self.epoch as u128 * self.reward_per_epoch;
        }

        if reward > 0 {
            Promise::new(env::predecessor_account_id()).transfer(NearToken::from_yoctonear(reward));
        }
    }

    pub fn recall_art_piece(
        &mut self,
        token_id: TokenId,
    ) -> Promise {
        require!(self.displayed_art_pieces.remove(&env::predecessor_account_id()).is_some(), "Art piece not displayed");
        self.rented_art_pieces.remove(&token_id);

        let promise = exchange::ext(self.art_pieces_account.clone())
            .nft_transfer(
                env::current_account_id(),
                env::predecessor_account_id(),
                token_id.clone(),
                None,
                None
            );

        promise.then(
            Self::ext(env::current_account_id())
                .recall_art_piece_callback(token_id),
        )
    }

    pub fn recall_art_piece_callback(
        &self,
        token_id: TokenId,
        #[callback_result] call_result: Result<String, PromiseError>,
    ) -> bool {
        if call_result.is_err() {
            env::log_str("Error");

            exchange::ext(self.art_pieces_account.clone())
            .nft_transfer(
                env::current_account_id(),
                env::predecessor_account_id(),
                token_id,
                None,
                None
            );
            return false;
        }

        env::log_str("Success");
        true
    }

    pub fn set_reward_per_epoch(&mut self, epoch: u64, reward_per_epoch: u128) {
        assert_eq!(
            env::predecessor_account_id(),
            env::current_account_id(),
            "Unauthorized"
        );

        self.epoch = epoch;
        self.reward_per_epoch = reward_per_epoch;
    }
}