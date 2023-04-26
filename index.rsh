'reach 0.1';

export const main = Reach.App(() => {
  setOptions({ALGOExitMode: 'DeleteAndCloseOutASAs'});
  const A = Participant('Admin', {
    params: Object({
      numTickets: UInt,
      cost: UInt,
      reachT: Token,
      day: UInt,// len in blocks
    }),
    winningNum: Fun([], UInt),
    launched: Fun([Contract], Null),
    checkWin: Fun([], Null),
  });
  const B = API('Buyer', {
    getTicket: Fun([Address], UInt),
    checkTicket: Fun([Address], Tuple(Bool, UInt)),
  });
  const V = View({
    cost: UInt,
    ticketsLeft: UInt,
  })
  init();
  A.only(() => {
    const {numTickets, cost, reachT, day} = declassify(interact.params);
  });
  A.publish(numTickets, cost, reachT, day);
  V.cost.set(cost);
  commit();
  A.pay([[1, reachT]]);
  A.interact.launched(getContract());

  const pMap = new Map(Address, UInt);
  const end = lastConsensusTime() + day;
  const [ticketsSold, tokensRec] = parallelReduce([1, 0])
    .define(() => {
      V.ticketsLeft.set((numTickets + 1) - ticketsSold);
    })
    .invariant(balance(reachT) == 1, "non-network token balance wrong")
    .invariant(balance() == tokensRec, "network token balance wrong")
    .while(lastConsensusTime() < end && ticketsSold < (numTickets + 1))
    .api_(B.getTicket, (addr) => {
      check(isNone(pMap[addr]), "sorry, you already have a ticket");
      return [cost, (ret) => {
        pMap[addr] = ticketsSold;
        ret(ticketsSold);
        return[ticketsSold + 1, tokensRec + cost];
      }]
    })
  commit();
  A.only(() => {
    const winningNum = declassify(interact.winningNum());
  });
  A.publish(winningNum);
  A.interact.checkWin();
 

  // allow users to come check their win
  const [winner] = parallelReduce([false])
    .invariant(winner ? balance() == 0 : balance() == tokensRec, "network token balance wrong")
    .invariant(winner ? balance(reachT) == 0 : balance(reachT) == 1, "non-network token balance wrong")
    .while(winner == false)
    .api_(B.checkTicket, (addr) => {
      check(isSome(pMap[addr]), "Sorry, you are not in the list");
      return[0, (ret) => {
        const num = fromSome(pMap[addr], 0);
        if(num == winningNum){
          ret([true, tokensRec]);
          transfer(1, reachT).to(addr);
          transfer(tokensRec).to(addr);
          delete pMap[addr];
          return [true];
        } else {
          ret([false, tokensRec]);
          delete pMap[addr];
          return [false];
        }
      }]
    })
  commit();
  exit();
})