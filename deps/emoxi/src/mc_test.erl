% Copyright (c) 2009, NorthScale, Inc.
% All rights reserved.

-module(mc_test).

-include("mc_entry.hrl").

-compile(export_all).

main() ->
    Config = [],

    AsciiAddrs = [mc_addr:local(ascii)],
    AsciiPool = mc_pool:create(ascii_pool, AsciiAddrs, Config,
                               [mc_bucket:create("default", AsciiAddrs,
                                                  Config)]),
    BinaryAddrs = [mc_addr:local(binary)],
    BinaryPool = mc_pool:create(binary_pool, BinaryAddrs, Config,
                                [mc_bucket:create("default", BinaryAddrs,
                                                  Config)]),
    Addrs2 = [mc_addr:local(ascii),
              mc_addr:local(binary)],
    Pool2 = mc_pool:create(pool2, Addrs2, Config,
                           [mc_bucket:create("default", Addrs2,
                                             Config)]),
    Addrs3 = [mc_addr:local(binary),
              mc_addr:local(binary)],
    Pool3 = mc_pool:create(pool3, Addrs3, Config,
                           [mc_bucket:create("default", Addrs3,
                                             Config)]),
    [mc_downstream_sup:start_link(),
     mc_downstream:start_link(),
     mc_accept:start_link(11300,
                     {mc_server_ascii,
                      mc_server_ascii_proxy, AsciiPool}),
     mc_accept:start_link(11400,
                     {mc_server_ascii,
                      mc_server_ascii_proxy, BinaryPool}),
     mc_accept:start_link(11500,
                     {mc_server_binary,
                      mc_server_binary_proxy, AsciiPool}),
     mc_accept:start_link(11600,
                     {mc_server_binary,
                      mc_server_binary_proxy, BinaryPool}),
     mc_accept:start_link(11233,
                     {mc_server_detect,
                      mc_server_detect, AsciiPool}),
     mc_accept:start_link(11244,
                     {mc_server_detect,
                      mc_server_detect, BinaryPool}),
     mc_accept:start_link(11255,
                     {mc_server_detect,
                      mc_server_detect, Pool2}),
     mc_accept:start_link(11266,
                     {mc_server_detect,
                      mc_server_detect, Pool3})].

% Paired with ./test/emoxi_test.py

main_mock() ->
    Config = [[{replica_n, 1},
               {replica_w, 1},
               {replica_r, 1}]],

    AsciiAddrs = [mc_addr:create("127.0.0.1:11311", ascii)],
    AsciiPool = mc_pool:create(default, AsciiAddrs, Config,
                               [mc_bucket:create("default", AsciiAddrs,
                                                  Config)]),
    {application:start(ns_server),
     mc_downstream:start_link(),
     mc_accept:start_link(11333,
                     {mc_server_detect,
                      mc_server_detect, AsciiPool})}.

% To build:
%   make clean && make
%
% To run tests:
%   erl -pa ebin -noshell -s mc_test test -s init stop
%
tests(mc) ->
    [mc_ascii,
     mc_client_ascii,
     mc_client_ascii_ac,
     mc_binary,
     mc_client_binary,
     mc_client_binary_ac,
     mc_bucket,
     mc_pool,
     mc_downstream
    ];

tests(emoxi) ->
    [util,
     cring,
     ketama
    ];

tests(emoxi_dyn) ->
    [vclock,
     stream
     % bootstrap,
     % dmerkle,
     % dmerkle_tree,
     % partition,
     % membership,     -- failing due to config to ns_config change.
     % storage_server, -- failing due to config to ns_config change.
     % storage_manager,
     % sync_manager
    ].

% For cmd-line...

test() -> test([mc, emoxi, emoxi_dyn]).

test([])         -> [];
test([X | Rest]) -> [ test_list(tests(X)) | test(Rest) ].

test_cover(Tests) ->
    cover:start(),
    cover:compile_directory("src", [{i, "include"}]),
    test_list(Tests),
    file:make_dir("tmp"),
    lists:foreach(
      fun (Test) ->
              {ok, _Cov} =
                  cover:analyse_to_file(
                    Test,
                    "tmp/" ++ atom_to_list(Test) ++ ".cov.html",
                    [html])
      end,
      Tests),
    ok.

test_list(Tests) ->
    process_flag(trap_exit, true),
    lists:foreach(
      fun (Test) ->
              io:format("  ~p...~n", [Test]),
              misc:rm_rf("./test/log"),
              application:start(ns_server),
              Test:test(),
              application:stop(ns_server)
      end,
      Tests),
    ok.

cucumber_features() -> ["rebalance"].

cucumber_step_modules() -> [].

cucumber() ->
    process_flag(trap_exit, true),
    CucumberStepModules = cucumber_step_modules(),
    CucumberFeatures = cucumber_features(),
    TotalStats =
        lists:foldl(
          fun (Feature, Acc) ->
                  {ok, Stats} =
                      cucumberl:run("./features/" ++ Feature ++ ".feature",
                                    CucumberStepModules),
                  cucumberl:stats_add(Stats, Acc)
          end,
          cucumberl:stats_blank(),
          CucumberFeatures),
    io:format("total stats: ~p~n", [TotalStats]),
    {ok, TotalStats}.

% Example:
%
%   repeat(mc_client_binary, test).
%
%   erl -pa ebin -s mc_test repeat mc_client_binary test
%
repeat([Mod, Fun])     -> repeat(Mod, Fun).
repeat(Mod, Fun)       -> repeat(Mod, Fun, []).
repeat(Mod, Fun, Args) -> repeat(Mod, Fun, Args, 1).
repeat(Mod, Fun, Args, N) ->
    case N rem 1000 of
        0 -> io:format("repeat ~p~n", [N]);
        _ -> ok
    end,
    erlang:apply(Mod, Fun, Args),
    repeat(Mod, Fun, Args, N + 1).

