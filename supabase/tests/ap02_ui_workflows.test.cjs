const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const html = fs.readFileSync('index.html', 'utf8');
function extract(start, end) {
  const from = html.indexOf(start);
  const to = html.indexOf(end, from);
  assert.ok(from >= 0 && to > from, 'could not extract handler: ' + start);
  return html.slice(from, to);
}
const inviteHandler = extract('window.addTrainerToTeam=async()=>{', '\nwindow.logout=');
const roleHandler = extract('window.changeTrainerRole=async(userId,newRole)=>{', '\nwindow.removeTrainer=');

function harness({invokeResult={data:{message:'Einladung erfolgreich'},error:null}, labelResult={error:null}, rpcResult={error:null}, loadError=null, roles=['trainer'], trainers=null}={}) {
  const calls=[];
  const statuses=[];
  const inputs={
    trainerLabelAdd:{value:'Test Trainer'},
    trainerEmailAdd:{value:'test@example.test'},
    trainerRoleAdd:{value:'trainer'}
  };
  const state={trainers:trainers || [{user_id:'user-2',roles,role:roles.includes('admin')?'admin':'trainer',admin_label:'Test Trainer',email:'test@example.test'}]};
  const context={
    window:{}, state, team:'team-1', currentUser:{id:'user-1'}, console,
    adminGuard:()=>true,
    showStatus:(message,type)=>statuses.push({message,type}),
    renderTrainerList:()=>calls.push({method:'renderTrainerList'}),
    loadApp:async()=>{calls.push({method:'loadApp'});if(loadError)throw loadError;},
    $: (id)=>inputs[id] || {value:''},
    getClient:()=>({
      functions:{invoke:async(name,options)=>{calls.push({method:'invoke',name,options});return invokeResult;}},
      rpc:async(name,args)=>{
        calls.push({method:'rpc',name,args});
        if(name==='admin_set_trainer_label') return labelResult;
        return rpcResult;
      }
    })
  };
  vm.createContext(context);
  vm.runInContext(inviteHandler,context);
  vm.runInContext(roleHandler,context);
  return {context,calls,statuses,inputs,state};
}

(async()=>{
  // Invitation happy path: invite endpoint, role/name RPCs, reload, success feedback.
  {
    const h=harness();
    await h.context.window.addTrainerToTeam();
    assert.ok(h.calls.some(c=>c.method==='invoke'&&c.name==='invite-trainer'));
    assert.ok(h.calls.some(c=>c.method==='rpc'&&c.name==='admin_set_trainer_label'));
    assert.ok(h.statuses.some(s=>s.type==='ok'&&s.message.includes('Einladung')));
  }
  // Label write failure must not misreport an already-sent invitation as failed.
  {
    const h=harness({labelResult:{error:{message:'label write denied'}}});
    await h.context.window.addTrainerToTeam();
    assert.ok(h.statuses.some(s=>s.type==='error'&&s.message.includes('Einladung und Rolle wurden gespeichert')));
    assert.ok(!h.statuses.some(s=>s.message.startsWith('Trainer konnte nicht eingeladen werden')));
  }
  // Refresh failure after a successful invitation must be reported as a refresh issue.
  {
    const h=harness({loadError:new Error('refresh failed')});
    await h.context.window.addTrainerToTeam();
    assert.ok(h.statuses.some(s=>s.message.includes('Die Ansicht konnte nicht aktualisiert werden')));
    assert.ok(!h.statuses.some(s=>s.message.startsWith('Trainer konnte nicht eingeladen werden')));
  }
  // Invitation endpoint failure must not be reported as success.
  {
    const h=harness({invokeResult:{data:null,error:{message:'invite failed'}}});
    await h.context.window.addTrainerToTeam();
    assert.ok(h.statuses.some(s=>s.type==='error'&&s.message.startsWith('Trainer konnte nicht eingeladen werden')));
    assert.ok(!h.calls.some(c=>c.method==='rpc'&&c.name==='admin_set_trainer_label'));
  }
  // Role addition must call the additive RPC and show success only after it resolves.
  {
    const h=harness({roles:['trainer']});
    await h.context.window.changeTrainerRole('user-2','admin');
    assert.ok(h.calls.some(c=>c.method==='rpc'&&c.name==='admin_add_team_role'&&c.args.p_role==='admin'));
    assert.ok(h.statuses.some(s=>s.type==='ok'&&s.message==='Rolle hinzugefügt.'));
  }
  // Removing one role must preserve the other role by calling only the remove-role RPC.
  {
    const h=harness({roles:['trainer','admin'],trainers:[{user_id:'user-2',roles:['trainer','admin'],role:'admin',admin_label:'Test Trainer',email:'test@example.test'},{user_id:'user-3',roles:['admin'],role:'admin',admin_label:'Other Admin',email:'other@example.test'}]});
    await h.context.window.changeTrainerRole('user-2','admin');
    assert.ok(h.calls.some(c=>c.method==='rpc'&&c.name==='admin_remove_team_role'&&c.args.p_role==='admin'));
    assert.ok(!h.calls.some(c=>c.method==='rpc'&&c.name==='admin_remove_team_role'&&c.args.p_role==='trainer'));
  }
  // The UI blocks removal of the final admin before any RPC is sent.
  {
    const h=harness({roles:['admin'],trainers:[{user_id:'user-2',roles:['admin'],role:'admin',admin_label:'Admin',email:'admin@example.test'}]});
    await h.context.window.changeTrainerRole('user-2','admin');
    assert.ok(h.statuses.some(s=>s.message.includes('Mindestens ein Admin muss erhalten bleiben')));
    assert.ok(!h.calls.some(c=>c.method==='rpc'));
  }
  // RPC denial must show an error and never claim that the role was changed.
  {
    const h=harness({rpcResult:{error:{message:'Nicht berechtigt'}}});
    await h.context.window.changeTrainerRole('user-2','admin');
    assert.ok(h.statuses.some(s=>s.type==='error'&&s.message.includes('Rolle konnte nicht geändert werden')));
    assert.ok(!h.statuses.some(s=>s.type==='ok'));
  }
  console.log('AP02 invitation and role-change flow tests passed (7 scenarios).');
})().catch(error=>{console.error(error);process.exit(1);});
