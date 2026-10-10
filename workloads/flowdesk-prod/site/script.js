const tickets=[
{id:1042,customer:"Mia Adams",initials:"MA",subject:"Unable to update billing details",meta:"2 min ago · Billing",status:"Open",priority:"High",agent:"Nicole",ai:"NA"},
{id:1041,customer:"James Miller",initials:"JM",subject:"Login keeps redirecting me",meta:"18 min ago · Technical",status:"In Progress",priority:"High",agent:"Thabo",ai:"TK"},
{id:1040,customer:"Ava Williams",initials:"AW",subject:"Question about my subscription",meta:"43 min ago · Account",status:"Waiting",priority:"Medium",agent:"Sarah",ai:"SA"},
{id:1039,customer:"Liam Brown",initials:"LB",subject:"Invoice for August",meta:"1 hr ago · Billing",status:"Resolved",priority:"Low",agent:"Nicole",ai:"NA"},
{id:1038,customer:"Noah Davis",initials:"ND",subject:"Feature request: dark mode",meta:"2 hrs ago · General",status:"Open",priority:"Low",agent:"Thabo",ai:"TK"},
{id:1037,customer:"Emma Wilson",initials:"EW",subject:"App is loading slowly",meta:"3 hrs ago · Technical",status:"In Progress",priority:"Medium",agent:"Sarah",ai:"SA"},
{id:1036,customer:"Olivia Taylor",initials:"OT",subject:"Can I change my plan?",meta:"4 hrs ago · Account",status:"Open",priority:"Medium",agent:"Nicole",ai:"NA"},
{id:1035,customer:"Lucas Moore",initials:"LM",subject:"Payment was charged twice",meta:"5 hrs ago · Billing",status:"Waiting",priority:"High",agent:"Thabo",ai:"TK"}
];
const agents=[["Nicole Marise","NM",68,8],["Thabo Khumalo","TK",82,11],["Sarah Adams","SA",54,6],["David Smith","DS",41,4]];
const customers=[["Mia Adams","MA","mia.adams@example.com","8 tickets"],["James Miller","JM","james.miller@example.com","5 tickets"],["Ava Williams","AW","ava.williams@example.com","12 tickets"],["Liam Brown","LB","liam.brown@example.com","3 tickets"],["Emma Wilson","EW","emma.wilson@example.com","7 tickets"],["Noah Davis","ND","noah.davis@example.com","4 tickets"]];
const $=s=>document.querySelector(s);
const esc=s=>String(s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[c]));
function statusClass(s){return s.toLowerCase().replace(" ","-")}
function priorityClass(s){return s.toLowerCase()}
function row(t){return `<div class="ticket-row" data-id="${t.id}"><div class="customer-avatar">${t.initials}</div><div><div class="ticket-title">${esc(t.subject)}</div><div class="ticket-meta">#${t.id} · ${esc(t.customer)} · ${esc(t.meta.split(" · ")[1])}</div></div><span class="badge ${statusClass(t.status)}">${t.status}</span><span class="badge ${priorityClass(t.priority)}">${t.priority}</span><div class="agent"><span class="mini-avatar">${t.ai}</span>${t.agent}</div></div>`}
function renderRecent(){ $("#recentTickets").innerHTML=tickets.slice(0,5).map(row).join("")}
function renderAll(){const q=($("#ticketSearch")?.value||"").toLowerCase(), st=$("#statusFilter")?.value||"All statuses", pr=$("#priorityFilter")?.value||"All priorities"; let list=tickets.filter(t=>(!q||`${t.subject} ${t.customer} ${t.id}`.toLowerCase().includes(q))&&(st==="All statuses"||t.status===st)&&(pr==="All priorities"||t.priority===pr)); $("#allTickets").innerHTML=list.length?list.map(row).join(""):`<div style="padding:40px;text-align:center;color:#8993a4;font-size:13px">No tickets match your filters.</div>`}
function renderWorkload(){$("#workload").innerHTML=agents.map(a=>`<div class="agent-row"><div class="mini-avatar">${a[1]}</div><div class="agent-info"><strong>${a[0]}</strong><small>${a[3]} active tickets</small><div class="progress-bar"><i style="width:${a[2]}%"></i></div></div><div class="agent-count">${a[2]}%</div></div>`).join("")}
function renderCustomers(){$("#customers").innerHTML=customers.map(c=>`<div class="customer-card"><div class="customer-avatar">${c[1]}</div><div><strong>${c[0]}</strong><small>${c[2]}</small><small>${c[3]}</small></div></div>`).join("")}
function renderTeam(){$("#teamGrid").innerHTML=agents.map(a=>`<div class="team-card"><div class="big-avatar">${a[1]}</div><strong>${a[0]}</strong><small>Support Agent</small><div class="team-stat"><span>${a[3]} active tickets</span><b>${a[2]}% workload</b></div><div class="progress-bar"><i style="width:${a[2]}%"></i></div></div>`).join("")}
function showView(name){document.querySelectorAll(".view").forEach(v=>v.classList.add("hidden")); $(`#${name}View`).classList.remove("hidden");document.querySelectorAll(".nav-item[data-view]").forEach(b=>b.classList.toggle("active",b.dataset.view===name)); if(name==="tickets")renderAll(); if(window.innerWidth<701) $(".sidebar").classList.remove("show")}
function createTicket(data){const initials=data.customer.split(" ").map(x=>x[0]).join("").slice(0,2).toUpperCase();tickets.unshift({id:1043+tickets.length-1,customer:data.customer,initials,subject:data.subject,meta:"Just now · "+data.category,status:"Open",priority:data.priority,agent:"Nicole",ai:"NM"});$("#openStat").textContent=Number($("#openStat").textContent)+1;$("#navCount").textContent=tickets.filter(t=>t.status!=="Resolved").length;renderRecent();renderAll();$("#ticketModal").classList.add("hidden");$("#ticketForm").reset();$("#toast").classList.remove("hidden");setTimeout(()=>$("#toast").classList.add("hidden"),2800)}
document.querySelectorAll(".nav-item[data-view]").forEach(b=>b.addEventListener("click",()=>showView(b.dataset.view)));
document.querySelectorAll("[data-view-link]").forEach(b=>b.addEventListener("click",()=>showView(b.dataset.viewLink)));
$("#newTicketBtn").onclick=()=>$("#ticketModal").classList.remove("hidden");$("#newTicketBtn2").onclick=()=>$("#ticketModal").classList.remove("hidden");$("#closeModal").onclick=()=>$("#ticketModal").classList.add("hidden");$("#ticketModal").addEventListener("click",e=>{if(e.target.id==="ticketModal")$("#ticketModal").classList.add("hidden")});
$("#ticketForm").addEventListener("submit",e=>{e.preventDefault();createTicket(Object.fromEntries(new FormData(e.target)))});
$("#ticketSearch").addEventListener("input",renderAll);$("#statusFilter").addEventListener("change",renderAll);$("#priorityFilter").addEventListener("change",renderAll);
$("#globalSearch").addEventListener("keydown",e=>{if(e.key==="Enter"){showView("tickets");$("#ticketSearch").value=e.target.value;renderAll()}});
$("#mobileMenu").onclick=()=>$(".sidebar").classList.toggle("show");
renderRecent();renderWorkload();renderCustomers();renderTeam();$("#navCount").textContent=tickets.filter(t=>t.status!=="Resolved").length;
