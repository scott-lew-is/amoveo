-module(test_txs).
-export([test/0, test/1, mine_blocks/1, absorb/1]).
 
test() ->
    unlocked = keys:status(),
    Pub = constants:master_pub(),
    Pub = keys:pubkey(),

    S = success,
    S = test(1),%create account, spend, delete %S = test(2),%repo tx
    S = test(3),%channel team close, channel grow
    %S = test(4),%channel repo
    S = test(5),%channel timeout
    S = test(6),%channel slash
    S = test(7),%existence
    S = test(14),%financial options
    S = test(12),%multiple bets in a single channel
    S = test(15),%automatic channel slash
    %warning! after running test(11), we can no longer run other tests. because test(11) mines blocks, so tx_pool:dump can no longer undo transactions.
    S = test(13),%testing governance
    S = test(11),%try out the oracle
    timer:sleep(300),
    S.
absorb(Tx) -> 
    %tx_pool_feeder:absorb_unsafe(Tx).
    tx_pool_feeder:absorb(Tx).
    %timer:sleep(400).
test(1) ->
    io:fwrite(" create_account tx"),
    %create account, spend, delete account
    BP = block:get_by_height_in_chain(0, headers:top()),
    PH = block:hash(BP),
    tx_pool:dump(),
    Trees = block:trees(BP),
    Accounts = trees:accounts(Trees),
    {NewPub,NewPriv} = testnet_sign:new_key(),

    Fee = 20,
    {Ctx, _} = create_account_tx:new(NewPub, 100000000, Fee, constants:master_pub(), Trees),
    Stx = keys:sign(Ctx),
    absorb(Stx),
    {Trees2,  _, _} = tx_pool:data(),
    Accounts2 = trees:accounts(Trees2),
    {Ctx2, _} = spend_tx:make(NewPub, 10, Fee, constants:master_pub(), Trees2, []),
    Stx2 = keys:sign(Ctx2),
    absorb(Stx2),
    {Trees3, _, _} = tx_pool:data(),
    Accounts3 = trees:accounts(Trees3),
    {Ctx3, _} = delete_account_tx:new(constants:master_pub(), NewPub, Fee, Trees3),
    Stx3 = testnet_sign:sign_tx(Ctx3, NewPub, NewPriv),
    absorb(Stx3),
    {Trees4, _, _} = tx_pool:data(),
    Accounts4 = trees:accounts(Trees4),
    {Ctx4, _} = create_account_tx:new(NewPub, 100000000, Fee, constants:master_pub(), Trees4),
    Stx4 = keys:sign(Ctx4),
    absorb(Stx4),

    {Trees5, _, Txs} = tx_pool:data(),
    BP2 = block:get_by_height(0),
    PH = block:hash(BP2),

    Block = block:make(block:block_to_header(BP2), Txs, Trees, constants:master_pub()),%1 is the master pub
    MBlock = block:mine2(Block, 1),
    Header = block:block_to_header(MBlock),
    headers:absorb([Header]),
    {true, _} = block:check(MBlock),
    success;
    
test(2) ->
    io:fwrite(" repo tx"),
    BP = block:get_by_height(0),
    PH = block:hash(BP),
    tx_pool:dump(),
    Trees = block:trees(BP),
    Accounts = trees:accounts(Trees),
    {NewPub,_NewPriv} = testnet_sign:new_key(),

    Fee = 20,
    {Ctx, _Proof} = create_account_tx:new(NewPub, 0, Fee, constants:master_pub(), Trees),
    Stx = keys:sign(Ctx),
    absorb(Stx),
    {Trees2, _, _} = tx_pool:data(),
    Accounts2 = trees:accounts(Trees2),

    {Ctx2, _} = repo_tx:make(NewPub, Fee, constants:master_pub(), Trees2),
    Stx2 = keys:sign(Ctx2),
    absorb(Stx2),
    {_, _, Txs} = tx_pool:data(),

    Block = block:mine2(block:make(block:block_to_header(BP), Txs, Trees, constants:master_pub()), 10),
    Header = block:block_to_header(Block),
    headers:absorb([Header]),
    {true, _} = block:check(Block),
    success;
test(3) ->
    io:fwrite(" new channel tx"),
    %new channel, grow channel, channel team close
    headers:dump(),
    block:initialize_chain(),
    tx_pool:dump(),
    BP = block:get_by_height(0),
    PH = block:hash(BP),
    Trees = block:trees(BP),
    Accounts = trees:accounts(Trees),
    {NewPub,NewPriv} = testnet_sign:new_key(),

    Fee = 20,
    Amount = 1000000,
    {Ctx, _Proof} = create_account_tx:new(NewPub, Amount, Fee, constants:master_pub(), Trees),
    Stx = keys:sign(Ctx),
    absorb(Stx),
    timer:sleep(100),
    {Trees2, _, _} = tx_pool:data(),
    Accounts2 = trees:accounts(Trees2),

    CID = 5,
    Entropy = 432,

    Delay = 30,
    {Ctx2, _} = new_channel_tx:make(CID, Trees2, constants:master_pub(), NewPub, 100, 200, Entropy, Delay, Fee),
    Stx2 = keys:sign(Ctx2),
    SStx2 = testnet_sign:sign_tx(Stx2, NewPub, NewPriv), 
    absorb(SStx2),
    {Trees3, _, _} = tx_pool:data(),
    Accounts3 = trees:accounts(Trees3),

    {Ctx3, _} = grow_channel_tx:make(CID, Trees3, 22, 33, Fee),
    Stx3 = keys:sign(Ctx3),
    SStx3 = testnet_sign:sign_tx(Stx3, NewPub, NewPriv),
    absorb(SStx3),
    {Trees4, _, _} = tx_pool:data(),
    Accounts4 = trees:accounts(Trees4),

    {Ctx4, _} = channel_team_close_tx:make(CID, Trees4, 0, [], Fee),
    Stx4 = keys:sign(Ctx4),
    SStx4 = testnet_sign:sign_tx(Stx4, NewPub, NewPriv),
    absorb(SStx4),
    {_,_,Txs} = tx_pool:data(),

    Block = block:mine2(block:make(block:block_to_header(BP), Txs, Trees, constants:master_pub()), 10),
    Header = block:block_to_header(Block),
    headers:absorb([Header]),
    {true, _} = block:check(Block),
    success;
    
test(5) -> 
    %channel solo close, channel timeout
    io:fwrite("channel solo close tx"),
    headers:dump(),
    block:initialize_chain(),
    tx_pool:dump(),
    BP = block:get_by_height(0),
    PH = block:hash(BP),
    Trees = block:trees(BP),
    Accounts = trees:accounts(Trees),
    {NewPub,NewPriv} = testnet_sign:new_key(),
    
    Fee = 20,
    Amount = 1000000,
    {Ctx, _Proof} = create_account_tx:new(NewPub, Amount, Fee, constants:master_pub(), Trees),
    Stx = keys:sign(Ctx),
    absorb(Stx),
    {Trees2, _, _} = tx_pool:data(),
    Accounts2 = trees:accounts(Trees2),
    
    CID = 5,
    Entropy = 432,
    Delay = 0,
    
    {Ctx2, _} = new_channel_tx:make(CID, Trees2, constants:master_pub(), NewPub, 10000, 20000, Entropy, Delay, Fee),
    Stx2 = keys:sign(Ctx2),
    SStx2 = testnet_sign:sign_tx(Stx2, NewPub, NewPriv), 
    absorb(SStx2),
    {Trees3, _, _} = tx_pool:data(),
    Accounts3 = trees:accounts(Trees3),
    
    Code = compiler_chalang:doit(<<"int 50">>),%channel nonce is 1, sends 50.
    Delay = 0,
    ChannelNonce = 0,
    Bet = spk:new_bet(Code, Code, 50, []),
    ScriptPubKey = keys:sign(spk:new(constants:master_pub(), NewPub, CID, [Bet], 10000, 10000, ChannelNonce+1, Delay, Entropy)),
    SignedScriptPubKey = testnet_sign:sign_tx(ScriptPubKey, NewPub, NewPriv), 
    ScriptSig = compiler_chalang:doit(<<" int 0 int 1 ">>),
    {Ctx3, _} = channel_solo_close:make(constants:master_pub(), Fee, SignedScriptPubKey, [ScriptSig], Trees3), 
    Stx3 = keys:sign(Ctx3),
    absorb(Stx3),
    %mine_blocks(1),
    timer:sleep(500),
    {Trees4, _, _Txs} = tx_pool:data(),
    Accounts4 = trees:accounts(Trees4),
    {Ctx4, _} = channel_timeout_tx:make(constants:master_pub(),Trees4,CID,[],Fee),
    Stx4 = keys:sign(Ctx4),
    absorb(Stx4),
    {_, _, Txs} = tx_pool:data(),

    Block = block:mine2(block:make(block:block_to_header(BP), Txs, Trees, constants:master_pub()), 10),
    Header = block:block_to_header(Block),
    headers:absorb([Header]),
    {true, _} = block:check(Block),
    success;
test(6) -> 
    io:fwrite("channel slash tx"),
    headers:dump(),
    block:initialize_chain(),
    tx_pool:dump(),
    BP = block:get_by_height(0),
    PH = block:hash(BP),
    tx_pool:dump(),
    Trees = block:trees(BP),
    Accounts = trees:accounts(Trees),
    {NewPub,NewPriv} = testnet_sign:new_key(),

    Fee = 20,
    Amount = 1000000,
    {Ctx, _Proof} = create_account_tx:new(NewPub, Amount, Fee, constants:master_pub(), Trees),
    Stx = keys:sign(Ctx),
    absorb(Stx),
    {Trees2, _, _} = tx_pool:data(),
    Accounts2 = trees:accounts(Trees2),

    CID = 5,
    Entropy = 432,

    {Ctx2, _} = new_channel_tx:make(CID, Trees2, constants:master_pub(), NewPub, 100, 200, Entropy, 10, Fee),
    Stx2 = keys:sign(Ctx2),
    SStx2 = testnet_sign:sign_tx(Stx2, NewPub, NewPriv), 
    absorb(SStx2),
    {Trees3, _, _} = tx_pool:data(),
    Accounts3 = trees:accounts(Trees3),
    
    Code = compiler_chalang:doit(<<"int 50">>),%channel nonce is 1, sends 50.
    Delay = 0,
    ChannelNonce = 0,
    Bet = spk:new_bet(Code, Code, 50, []),
    ScriptPubKey = keys:sign(spk:new(constants:master_pub(), NewPub, CID, [Bet], 10000, 10000, ChannelNonce+1, Delay, Entropy)),
    SignedScriptPubKey = testnet_sign:sign_tx(ScriptPubKey, NewPub, NewPriv), 
    ScriptSig = compiler_chalang:doit(<<" int 0 int 1 ">>),
    {Ctx3, _} = channel_solo_close:make(constants:master_pub(), Fee, SignedScriptPubKey, [ScriptSig], Trees3), 
    Stx3 = keys:sign(Ctx3),
    absorb(Stx3),
    {Trees4, _, _} = tx_pool:data(),
    Accounts4 = trees:accounts(Trees4),

    ScriptSig2 = compiler_chalang:doit(<<" int 0 int 2 ">>),
    {Ctx4, _} = channel_slash_tx:make(NewPub,Fee,SignedScriptPubKey,[ScriptSig2],Trees4),
    Stx4 = testnet_sign:sign_tx(Ctx4, NewPub, NewPriv),
    %Stx4 = keys:sign(Ctx4, Accounts4),
    absorb(Stx4),
    {Trees5, _, _} = tx_pool:data(),
    Accounts5 = trees:accounts(Trees5),

    ScriptSig3 = compiler_chalang:doit(<<" int 0 int 3 ">>),
    {Ctx5, _} = channel_slash_tx:make(constants:master_pub(),Fee,SignedScriptPubKey,[ScriptSig3],Trees5),
    Stx5 = keys:sign(Ctx5),
    %Stx4 = keys:sign(Ctx4, Accounts4),
    absorb(Stx5),
    {Trees6, _, _Txs2} = tx_pool:data(),
    Accounts6 = trees:accounts(Trees6),

    {Ctx6, _} = channel_timeout_tx:make(constants:master_pub(),Trees6,CID,[],Fee),
    Stx6 = keys:sign(Ctx6),
    absorb(Stx6),
    {Trees7, _, Txs} = tx_pool:data(),
    Channels7 = trees:channels(Trees7),
    {_, empty, _} = channels:get(1, Channels7),

    Block = block:mine2(block:make(block:block_to_header(BP), Txs, Trees, constants:master_pub()), 10),
    Header = block:block_to_header(Block),
    headers:absorb([Header]),
    {true, _} = block:check(Block),
    success;

test(7) ->
    %existence tx
    headers:dump(),
    block:initialize_chain(),
    io:fwrite("existence test"),
    S = <<"test data">>,
    tx_pool:dump(),
    {Trees,_,_} = tx_pool:data(),
    Accounts = trees:accounts(Trees),
    C = existence:new(testnet_hasher:doit(S)),
    {Tx, _} = existence_tx:make(constants:master_pub(), 1000, C, Trees),
    Stx = keys:sign(Tx),
    absorb(Stx),
    {Trees2, _, _} = tx_pool:data(),
    ETree = trees:existence(Trees2),
    {_, C, _} = existence:get(existence:hash(C), ETree),
    BP = block:get_by_height(0),
    PH = block:hash(BP),
    {_, _, Txs} = tx_pool:data(),
    Block = block:mine2(block:make(block:block_to_header(BP), Txs, Trees, constants:master_pub()), 10),
    Header = block:block_to_header(Block),
    headers:absorb([Header]),
    {true, _} = block:check(Block),
    success;
test(11) ->
    io:fwrite("testing an oracle"),
    %testing the oracle
    %launch an oracle with oracle_new
    Question = <<>>,
    OID = 1,
    Fee = 20,
    headers:dump(),
    block:initialize_chain(),
    tx_pool:dump(),
    {Trees,_,_Txs} = tx_pool:data(),
    Accounts = trees:accounts(Trees),
    {Tx, _} = oracle_new_tx:make(constants:master_pub(), Fee, Question, 1, OID, constants:initial_difficulty(), 0, 0, 0, Trees),
    Stx = keys:sign(Tx),
    absorb(Stx),
    timer:sleep(150),
    mine_blocks(5),
    timer:sleep(150),
    {Trees2, _, _} = tx_pool:data(),
    Accounts2 = trees:accounts(Trees2),
    %make some bets in the oracle with oracle_bet
    Governance2 = trees:governance(Trees2),
    OIL = governance:get_value(oracle_initial_liquidity, Governance2),
    {Tx2, _} = oracle_bet_tx:make(constants:master_pub(), Fee, OID, 1, OIL, Trees2), 
    Stx2 = keys:sign(Tx2),
    absorb(Stx2),
    %timer:sleep(100),

    mine_blocks(1),
    timer:sleep(150),
    {Trees3, _, _} = tx_pool:data(),
    Accounts3 = trees:accounts(Trees3),
    %close the oracle with oracle_close
    {Tx3, _} = oracle_close_tx:make(constants:master_pub(),Fee, OID, Trees3),
    Stx3 = keys:sign(Tx3),
    absorb(Stx3),
    timer:sleep(100),

    {Trees4, _, _} = tx_pool:data(),
    Accounts4 = trees:accounts(Trees4),
    %get your spare money out with oracle_unmatched
    Oracles = trees:oracles(Trees4),
    {_, Oracle, _} = oracles:get(OID, Oracles),
    Orders = oracles:orders(Oracle),
    {OrderID, _} = orders:head_get(Orders),%This only works because there is exactly 1 order in the order book.
    {Tx4, _} = oracle_unmatched_tx:make(constants:master_pub(), Fee, OID, Trees4),
    Stx4 = keys:sign(Tx4),
    absorb(Stx4),
    timer:sleep(100),

    {Trees5, _, _} = tx_pool:data(),
    Accounts5 = trees:accounts(Trees5),
    %get your shares out with oracle_shares
    {Tx5, _}=oracle_shares_tx:make(constants:master_pub(), Fee, OID, Trees5),
    Stx5 = keys:sign(Tx5),
    absorb(Stx5),
    timer:sleep(100),
    {_,Height6,Txs} = tx_pool:data(),
    BP = block:get_by_height(Height6),
    Block = block:mine2(block:make(block:block_to_header(BP), Txs, block:trees(BP), constants:master_pub()), 10),
    Header = block:block_to_header(Block),
    headers:absorb([Header]),
    {true, _} = block:check(Block),
    success;
test(12) ->
    io:fwrite("multiple bets in a single channel"),
    headers:dump(),
    block:initialize_chain(),
    tx_pool:dump(),
    {Trees, _, _Txs} = tx_pool:data(),
    Accounts = trees:accounts(Trees),
    {NewPub,NewPriv} = testnet_sign:new_key(),
    
    Fee = 20,
    Amount = 1000000,
    {Ctx, _Proof} = create_account_tx:new(NewPub, Amount, Fee, constants:master_pub(), Trees),
    Stx = keys:sign(Ctx),
    absorb(Stx),
    {Trees2, _, _} = tx_pool:data(),
    Accounts2 = trees:accounts(Trees2),
    
    CID = 5,
    Entropy = 432,
    Delay = 0,
    
    {Ctx2, _} = new_channel_tx:make(CID, Trees2, constants:master_pub(), NewPub, 10000, 20000, Entropy, Delay, Fee),
    Stx2 = keys:sign(Ctx2),
    SStx2 = testnet_sign:sign_tx(Stx2, NewPub, NewPriv), 
    absorb(SStx2),
    {Trees3, _, _} = tx_pool:data(),
    Accounts3 = trees:accounts(Trees3),
    
    Code = compiler_chalang:doit(<<"int 50">>),%channel nonce is 1, sends 50.
    Code2 = compiler_chalang:doit(<<"int 50">>),%channel nonce is 1, sends 50.
    Delay = 0,
    ChannelNonce = 0,
    Bet = spk:new_bet(Code, Code, 50, []),
    Bet2 = spk:new_bet(Code2, Code2, 50, []),
    ScriptPubKey = keys:sign(spk:new(constants:master_pub(), NewPub, CID, [Bet, Bet2], 10000, 10000, ChannelNonce+1, Delay, Entropy)),
    SignedScriptPubKey = testnet_sign:sign_tx(ScriptPubKey, NewPub, NewPriv), 
    ScriptSig = compiler_chalang:doit(<<" int 0 int 1 ">>),
    ScriptSig2 = compiler_chalang:doit(<<" int 0 int 2 ">>),
    {Ctx3, _} = channel_solo_close:make(constants:master_pub(), Fee, SignedScriptPubKey, [ScriptSig, ScriptSig2], Trees3), 
    Stx3 = keys:sign(Ctx3),
    absorb(Stx3),
    timer:sleep(500),
    {Trees4, Height4, _} = tx_pool:data(),
    Accounts4 = trees:accounts(Trees4),
    {Ctx4, _} = channel_timeout_tx:make(constants:master_pub(),Trees4,CID,[],Fee),
    Stx4 = keys:sign(Ctx4),
    absorb(Stx4),
    BP = block:get_by_height(Height4),
    PH = block:hash(BP),
    {_,_,Txs} = tx_pool:data(),
    Block = block:mine2(block:make(block:block_to_header(BP), Txs, block:trees(BP), constants:master_pub()), 10),
    Header = block:block_to_header(Block),
    headers:absorb([Header]),
    {true, _} = block:check(Block),
    success;
test(13) ->
    %testing the governance
    %launch an oracle with oracle_new, close it on state "bad", 
    io:fwrite("test governance"),
    Question = <<>>,
    OID = 6,
    Fee = 20,
    headers:dump(),
    block:initialize_chain(),
    tx_pool:dump(),
    timer:sleep(100),
    Diff = constants:initial_difficulty(),
    {Trees,_,_} = tx_pool:data(),
    {Tx, _} = oracle_new_tx:make(constants:master_pub(), Fee, Question, 1, OID, Diff, 0, 0, 0, Trees),
    Stx = keys:sign(Tx),
    absorb(Stx),

    mine_blocks(2),
    {Trees2, _, _} = tx_pool:data(),
    %close the oracle with oracle_close
    {Tx2, _} = oracle_close_tx:make(constants:master_pub(),Fee, OID, Trees2),
    Stx2 = keys:sign(Tx2),
    absorb(Stx2),
    OID2 = 2,
    {Trees3,_,_} = tx_pool:data(),
    {Tx3, _} = oracle_new_tx:make(constants:master_pub(), Fee, Question, 1, OID2, Diff, OID, 1, 5, Trees3),
    Stx3 = keys:sign(Tx3),
    absorb(Stx3),

    Question2 = <<"1+1=2">>,
    OID3 = 3,
    {Trees4,_,_} = tx_pool:data(),
    {Tx4, _} = oracle_new_tx:make(constants:master_pub(), Fee, Question2, 1, OID3, Diff div 2, OID, 0, 0, Trees4),
    Stx4 = keys:sign(Tx4),
    absorb(Stx4),

    {_,H,Txs} = tx_pool:data(),
    BP = block:get_by_height(H),
    Block = block:mine2(block:make(block:block_to_header(BP), Txs, block:trees(BP), constants:master_pub()), 10),
    Header = block:block_to_header(Block),
    headers:absorb([Header]),
    {true, _} = block:check(Block),

    success;
test(14) -> 
    %options
    io:fwrite("options derivatives enforcement"),
    headers:dump(),
    block:initialize_chain(),
    tx_pool:dump(),
    BP = block:get_by_height(0),
    PH = block:hash(BP),
    Trees = block:trees(BP),
    Accounts = trees:accounts(Trees),
    {NewPub,NewPriv} = testnet_sign:new_key(),

    Fee = 20,
    Amount = 1000000,
    {Ctx, _Proof} = create_account_tx:new(NewPub, Amount, Fee, constants:master_pub(), Trees),
    Stx = keys:sign(Ctx),
    absorb(Stx),
    {Trees2, _, _} = tx_pool:data(),
    Accounts2 = trees:accounts(Trees2),

    CID = 5,
    Entropy = 432,

    {Ctx2, _} = new_channel_tx:make(CID, Trees2, constants:master_pub(), NewPub, 100, 200, Entropy, 10, Fee),
    Stx2 = keys:sign(Ctx2),
    SStx2 = testnet_sign:sign_tx(Stx2, NewPub, NewPriv), 
    absorb(SStx2),
    {Trees3, _, _} = tx_pool:data(),
    Accounts3 = trees:accounts(Trees3),
    
    Code = compiler_chalang:doit(<<"int 50">>),%channel nonce is 1, sends 50.
    Delay = 0,
    ChannelNonce = 0,
    Bet = spk:new_bet(Code, Code, 50, []),
    ScriptPubKey = keys:sign(spk:new(constants:master_pub(), NewPub, CID, [Bet], 10000, 10000, ChannelNonce+1, Delay, Entropy)),
    SignedScriptPubKey = testnet_sign:sign_tx(ScriptPubKey, NewPub, NewPriv), 
    ScriptSig = compiler_chalang:doit(<<" int 0 int 1 ">>),
    {Ctx3, _} = channel_solo_close:make(constants:master_pub(), Fee, SignedScriptPubKey, [ScriptSig], Trees3), 
    Stx3 = keys:sign(Ctx3),
    absorb(Stx3),
    {Trees4, _, _} = tx_pool:data(),
    Accounts4 = trees:accounts(Trees4),

    ScriptSig2 = compiler_chalang:doit(<<" int 0 int 2 ">>),
    {Ctx4, _} = channel_slash_tx:make(NewPub,Fee,SignedScriptPubKey,[ScriptSig2],Trees4),
    Stx4 = testnet_sign:sign_tx(Ctx4, NewPub, NewPriv),
    %Stx4 = keys:sign(Ctx4, Accounts4),
    absorb(Stx4),
    {Trees5, _, _} = tx_pool:data(),
    Accounts5 = trees:accounts(Trees5),

    {Ctx5, _} = grow_channel_tx:make(CID, Trees5, 22, 33, Fee),
    Stx5 = keys:sign(Ctx5),
    SStx5 = testnet_sign:sign_tx(Stx5, NewPub, NewPriv),
    absorb(SStx5),

    {Trees6, _, _Txs2} = tx_pool:data(),
    Accounts6 = trees:accounts(Trees6),

    {Ctx6, _} = channel_timeout_tx:make(constants:master_pub(),Trees6,CID,[],Fee),
    Stx6 = keys:sign(Ctx6),
    absorb(Stx6),
    BP2 = block:get_by_height(0),
    PH = block:hash(BP2),

    {_,_,Txs} = tx_pool:data(),
    Block = block:mine2(block:make(block:block_to_header(BP), Txs, Trees, constants:master_pub()), 10),
    Header = block:block_to_header(Block),
    headers:absorb([Header]),
    {true, _} = block:check(Block),
    success;

test(15) ->
    %If your partner tries closing at a low-nonced channel state, your node needs to automatically create a channel_slash to stop them.
    io:fwrite("channel slash automatic"),
    headers:dump(),
    block:initialize_chain(),
    tx_pool:dump(),
    BP = block:get_by_height(0),
    PH = block:hash(BP),
    Trees = block:trees(BP),
    Accounts = trees:accounts(Trees),
    {NewPub,NewPriv} = testnet_sign:new_key(),

    Fee = 20,
    Amount = 1000000,
    {Ctx, _Proof} = create_account_tx:new(NewPub, Amount, Fee, constants:master_pub(), Trees),
    Stx = keys:sign(Ctx),
    absorb(Stx),
    {Trees2, _, _} = tx_pool:data(),
    Accounts2 = trees:accounts(Trees2),

    CID = 5,
    Entropy = 432,

    {Ctx2, _} = new_channel_tx:make(CID, Trees2, constants:master_pub(), NewPub, 100, 200, Entropy, 10, Fee),
    Stx2 = keys:sign(Ctx2),
    SStx2 = testnet_sign:sign_tx(Stx2, NewPub, NewPriv), 
    absorb(SStx2),
    Code = compiler_chalang:doit(<<"int 50">>),%sends 50.
    Secret = compiler_chalang:doit(<<" int 0 int 2 ">>),
    %secrets:add(Code, Secret),
    %timer:sleep(100),
    {Trees3, _, _} = tx_pool:data(),
    Accounts3 = trees:accounts(Trees3),
    
    Delay = 0,
    ChannelNonce = 0,
    Bet = spk:new_bet(Code, Code, 50, []),
    SPK = spk:new(constants:master_pub(), NewPub, CID, [Bet], 10000, 10000, ChannelNonce+1, Delay, Entropy),
    TheySPK = testnet_sign:sign_tx(SPK, NewPub, NewPriv),
    CD = channel_feeder:new_cd(SPK, TheySPK, [Secret], [Secret], Entropy, CID),
    channel_manager:write(NewPub, CD),
    timer:sleep(100),
    ScriptPubKey = keys:sign(SPK),
    SignedScriptPubKey = testnet_sign:sign_tx(ScriptPubKey, NewPub, NewPriv), 
    ScriptSig = compiler_chalang:doit(<<" int 5 int 1 ">>),
    {Ctx3, _} = channel_solo_close:make(NewPub, Fee, SignedScriptPubKey, [ScriptSig], Trees3), 
    Stx3 = testnet_sign:sign_tx(Ctx3, NewPub, NewPriv),
    absorb(Stx3),
    timer:sleep(200),
    {_, _, Txs2} = tx_pool:data(),
    io:fwrite("~s", [packer:pack({slash_exists, Txs2})]),
    true = slash_exists(Txs2),%check that the channel_slash transaction exists in the tx_pool.
    %Block = block:mine(block:make(PH, Txs2, 1), 10000000000),%1 is the master pub
    %block:check2(Block),
    success.
slash_exists([]) -> false;
slash_exists([Tx|T]) ->
    is_slash(Tx) or slash_exists(T).
is_slash(STx) ->
    Tx = testnet_sign:data(STx),
    channel_slash_tx:is_tx(Tx).
	     
mine_blocks(Many) when Many < 1 -> ok;
mine_blocks(Many) ->
    %only works if you set the difficulty very low.
    Top = headers:top(),
    PB = block:get_by_hash(Top),
    {_, _, Txs} = tx_pool:data(),
    Block = block:make(Top, Txs, block:trees(PB), keys:pubkey()),
    block:mine(Block, 10),
    timer:sleep(1000),
    mine_blocks(Many-1).
