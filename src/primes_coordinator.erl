%%%-------------------------------------------------------------------
%%% @author Alvaro Videla
%%% @copyright (C) 2014, Alvaro Videla
%%% @doc
%%%
%%% @end
%%% Created : 15 Feb 2014 by Alvaro Videla <avidela@avidela.local>
%%%-------------------------------------------------------------------
-module(primes_coordinator).

-behaviour(gen_server).

%% API
-export([start_link/2]).

-export([collect/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {n, wait, seen = 0, values = [], parent}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(Parent, N) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [Parent, N], []).

collect(Pid, Val) ->
    gen_server:cast(Pid, {collect, Val}).


%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([Parent, N]) ->
    Half = N div 2,
    create_processes(Half),
    {ok, #state{n = N, wait = Half, parent = Parent}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({collect, Val}, #state{wait   = N,
                                   seen   = S,
                                   values = Vals,
                                   parent = P} = State) ->
    S2 = S+1,
    case S2 =:= N of
        true ->
            Primes = filtermap(
                       fun({Pred, Num}) ->
                               {Pred, maybe_make_prime(Num)}
                       end,
                       Vals),
            primes_sieve:show_sieve(P, Primes),
            {stop, normal, State};
        false ->
            {noreply, State#state{seen = S2, values = [Val|Vals]}}
    end;

handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

create_processes(N) ->
    create_processes(0, N).

create_processes(N, N) ->
    ok;
create_processes(Curr, N) ->
    primes_node:start_link(Curr+1, self()),
    create_processes(Curr+1, N).

maybe_make_prime(K) ->
    K * 2 + 1.

%% adapted from erlang.org since lists:filtermap appears only on new
%% versions of Erlang
filtermap(Fun, List1) ->
    lists:foldr(fun(Elem, Acc) ->
                        case Fun(Elem) of
                            {true, Value} -> [Value|Acc];
                            {false, _} -> Acc
                        end
                end, [], List1).
