import { loadStdlib } from "@reach-sh/stdlib";
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib({REACH_NO_WARN: 'Y'});
const MAX = 3;

const sbal = stdlib.parseCurrency(50);
const accA = await stdlib.newTestAccount(sbal);
const token = await stdlib.launchToken(accA, "Reach Token", "reachT", {supply: MAX});
const ctcA = accA.contract(backend);
const fmt = (x) => stdlib.formatCurrency(x, 4);
const getBalance = async (who) => fmt(await stdlib.balanceOf(who));


let users = [];
const startBuyers = async () => {
  const runBuyer = async (i) => {
    console.log(`Starting buyer number: ${i}`);
    const acc = await stdlib.newTestAccount(sbal);
    console.log(`The accounts address is ${stdlib.formatAddress(acc.getAddress())}`);
    const ctc = acc.contract(backend, ctcA.getInfo());
    await acc.tokenAccept(token.id);
    const beforeBal = await getBalance(acc);
    users.push([acc, ctc, beforeBal]);
    

    try{
      const cost = await ctc.unsafeViews.cost();
      console.log(`The user sees the cost is ${stdlib.formatCurrency(cost)}`);
      const left = await ctc.unsafeViews.ticketsLeft();
      console.log(`The user sees the number of tickets left: ${left}`);
      const n = await ctc.apis.Buyer.getTicket(acc.getAddress());
      console.log(`This users ticket is number: ${n}`);
    } catch (e) {
      console.log(`The call errored with: ${e}`);
    }
  }
  for(let i = 0; i < MAX; i++){
    await runBuyer(i);
  }
  // await runBuyer(1);
  // await runBuyer(2);
  // await runBuyer(3);
};// end of startBuyers

const checkTickets = async () => {
  let flag = false;
  for(const [acc, ctc, beforeBal] of users){
    if(!flag){
      try{
        const addr = stdlib.formatAddress(acc.getAddress());
        const [b, total] = await ctc.apis.Buyer.checkTicket(addr);
        console.log(`User: ${addr} sees their number matched is: ${b}`);
        flag = b ? true : false;
        if(flag){
          const afterBal = await getBalance(acc);
          console.log(`User: ${addr} just won ${stdlib.formatCurrency(total)} ${stdlib.standardUnit}S!`);
          //console.log(`User: ${addr} had ${beforeBal} ${stdlib.standardUnit} and now has ${afterBal} ${stdlib.standardUnit}`);
        } else {
          console.log(`Sorry, you didn't win this time. Prize pool: ${stdlib.formatCurrency(total)}`);
        }
      } catch (e) {
        console.log(`The checkTicket call errored with ${e}`);
      }
    }
  };
};// end of checkTickets

await ctcA.p.Admin({
  params: {
    numTickets: MAX,
    cost: stdlib.parseCurrency(5),
    reachT: token.id,
    day: 20,// in blocks 
  },
  launched: (c) => {
    console.log(`Ready at contract ${c}`);
    startBuyers();
  },
  winningNum: () => {
    const num = Math.floor(Math.random() * MAX) + 1;
    console.log(`The winning number is: ${num}`);
    return num;
  },
  checkWin: async () => {
    console.log(`Admin is ready to start checking tickets`);
    await checkTickets();
  },
})