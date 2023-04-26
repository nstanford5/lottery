/**
 * Build this similar to the NFT Raffle
 * Simulate a lottery drawing, best as possible
 */
'reach 0.1';

export const main = Reach.App(() => {
  setOptions({ALGOExitMode: 'DeleteAndCloseOutASAs'});
  const A = Participant('Admin', {
    params: Object({
      numTickets: UInt,
      reachT: Token,
      day: UInt,// len in blocks
    }),
    winningNum: Fun([], UInt),
    launched: Fun([Contract], Null),
    checkWin: Fun([], Null),
  });
  const B = API('Buyer', {
    getTicket: Fun([Address], UInt),
    checkTicket: Fun([Address], Bool),
  });
  init();
  A.only(() => {
    const {numTickets, reachT, day} = declassify(interact.params);
  });
  A.publish(numTickets, reachT, day);
  commit();
  A.pay([[1, reachT]]);
  A.interact.launched(getContract());

  const pMap = new Map(Address, UInt);
  const end = lastConsensusTime() + day;
  const [ticketsSold] = parallelReduce([1])
    .invariant(balance(reachT) == 1, "non-network token balance wrong")
    .invariant(balance() == 0, "network token balance wrong")
    //.while(ticketsSold < numTickets)
    .while(lastConsensusTime() < end && ticketsSold < (numTickets + 1))
    .api_(B.getTicket, (addr) => {
      check(isNone(pMap[addr]), "sorry, you already have a ticket");
      return [0, (ret) => {
        pMap[addr] = ticketsSold;
        ret(ticketsSold);
        return[ticketsSold + 1];
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
    .invariant(balance() == 0, "network token balance wrong")
    .invariant(winner ? balance(reachT) == 0 : balance(reachT) == 1, "non-network token balance wrong")
    .while(winner == false)
    .api_(B.checkTicket, (addr) => {
      check(isSome(pMap[addr]), "Sorry, you are not in the list");
      return[0, (ret) => {
        const num = fromSome(pMap[addr], 0);
        if(num == winningNum){
          ret(true);
          transfer(1, reachT).to(addr);
          delete pMap[addr];
          return [true];
        } else {
          ret(false);
          delete pMap[addr];
          return [false];
        }
      }]
    })
  commit();
  exit();
})