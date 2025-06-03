use std::{collections::HashMap, hash::Hash, ops::Deref};

// Find all our documentation at https://docs.near.org
use near_sdk::{assert_one_yocto, env, json_types::U64, log, near, require, collections::UnorderedSet, AccountId, BorshStorageKey, PanicOnDefault};
use near_contract_standards::non_fungible_token::{core::NonFungibleTokenCore, events::NftTransfer, metadata::TokenMetadata, NonFungibleToken, Token, TokenId};

#[derive(BorshStorageKey)]
#[near]
enum StorageKey {
    NonFungibleToken,
    TokensPerOwner { account_hash: Vec<u8> },
}

// Define the contract structure
#[near(contract_state)]
#[derive(PanicOnDefault)]
pub struct Contract {
    art_pieces: NonFungibleToken,
}

// Implement the contract structure
#[near]
impl Contract {
    #[init]
    #[private] // only callable by the contract's account
    pub fn init() -> Self {
        Self {
            art_pieces: NonFungibleToken::new::<_, StorageKey, StorageKey, StorageKey>(
                StorageKey::NonFungibleToken,
                env::current_account_id(),
                None,
                None,
                None
            ),
        }
    }

    /// Mint a new token with ID=`token_id` belonging to `token_owner_id`.
    #[payable]
    pub fn nft_mint(
        &mut self,
        token_id: TokenId,
        token_owner_id: AccountId,
    ) -> Token {
        assert_eq!(
            env::predecessor_account_id(),
            self.art_pieces.owner_id,
            "Unauthorized"
        );
        self.internal_mint(token_id, token_owner_id, None)
    }

    pub fn nft_transfer(
        &mut self,
        sender_id: AccountId,
        receiver_id: AccountId,
        token_id: TokenId,
        approval_id: Option<u64>,
        memo: Option<String>,
    ) {
        self.internal_transfer(&sender_id, &receiver_id, &token_id, approval_id, memo);
    }
}

/// Private functions
impl Contract {
    /// Transfer token_id from `from` to `to`
    ///
    /// Do not perform any safety checks or do any logging
    fn internal_transfer_unguarded(
        &mut self,
        #[allow(clippy::ptr_arg)] token_id: &TokenId,
        from: &AccountId,
        to: &AccountId,
    ) {
        // update owner
        self.art_pieces.owner_by_id.insert(token_id, to);

        // if using Enumeration standard, update old & new owner's token lists
        if let Some(tokens_per_owner) = &mut self.art_pieces.tokens_per_owner {
            // owner_tokens should always exist, so call `unwrap` without guard
            let mut owner_tokens = tokens_per_owner.get(from).unwrap_or_else(|| {
                env::panic_str("Unable to access tokens per owner in unguarded call.")
            });
            owner_tokens.remove(token_id);
            if owner_tokens.is_empty() {
                tokens_per_owner.remove(from);
            } else {
                tokens_per_owner.insert(from, &owner_tokens);
            }

            let mut receiver_tokens = tokens_per_owner.get(to).unwrap_or_else(|| {
                UnorderedSet::new(StorageKey::TokensPerOwner {
                    account_hash: env::sha256(to.as_bytes()),
                })
            });
            receiver_tokens.insert(token_id);
            tokens_per_owner.insert(to, &receiver_tokens);
        }
    }

    /// Transfer from current owner to receiver_id, checking that sender is allowed to transfer.
    /// Clear approvals, if approval extension being used.
    /// Return previous owner and approvals.
    fn internal_transfer(
        &mut self,
        sender_id: &AccountId,
        receiver_id: &AccountId,
        #[allow(clippy::ptr_arg)] token_id: &TokenId,
        approval_id: Option<u64>,
        memo: Option<String>,
    ) -> (AccountId, Option<HashMap<AccountId, u64>>) {
        let owner_id =
            self.art_pieces.owner_by_id.get(&token_id).unwrap_or_else(|| env::panic_str("Token not found"));

        // clear approvals, if using Approval Management extension
        // this will be rolled back by a panic if sending fails
        let approved_account_ids =
        self.art_pieces.approvals_by_id.as_mut().map(|by_id| by_id.remove(&token_id).unwrap_or_default());

        // check if authorized
        let sender_id = if sender_id != &owner_id {
            // Panic if approval extension is NOT being used
            let app_acc_ids = approved_account_ids
                .clone()
                .unwrap_or_default();

            // Approval extension is being used; get approval_id for sender.
            let actual_approval_id = app_acc_ids.get(sender_id);

            // If approval_id included, check that it matches
            require!(
                actual_approval_id == approval_id.as_ref(),
                format!(
                    "The actual approval_id {:?} is different from the given approval_id {:?}",
                    actual_approval_id, approval_id
                )
            );
            Some(sender_id)
        } else {
            None
        };

        require!(&owner_id != receiver_id, "Current and next owner must differ");

        self.internal_transfer_unguarded(token_id, &owner_id, receiver_id);

        NftTransfer {
            old_owner_id: &owner_id,
            new_owner_id: receiver_id,
            token_ids: &[token_id],
            authorized_id: sender_id.filter(|sender_id| **sender_id == owner_id).map(|f| f.deref()),
            memo: memo.as_deref(),
        }
        .emit();

        // return previous owner & approvals
        (owner_id, approved_account_ids)
    }
}
#[near]
impl Contract {
    fn internal_mint(
        &mut self,
        token_id: TokenId,
        token_owner_id: AccountId,
        token_metadata: Option<TokenMetadata>,
    ) -> Token {
        self.art_pieces
            .internal_mint(token_id, token_owner_id, token_metadata)
    }
}