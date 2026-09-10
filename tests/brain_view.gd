extends SceneTree

# Small explicit synthetic fixture for the production viewer and inspector controls.
var failures: Array[String]=[]
func verify(value: bool, description: String) -> void:
    print(('PASS: ' if value else 'FAIL: ')+description)
    if not value: failures.append(description)
func _initialize() -> void:
    checks.call_deferred()
func checks() -> void:
    var game=load('res://main.tscn').instantiate()
    game.settings_path=''
    root.add_child(game)
    game.director.set_process(false)
    await create_timer(0.5).timeout # Let the native audio mixer initialize before this short scene lifecycle.
    var panel=game.brain_view
    var view={'ids':['11','22','33','44'],'xyz':[[-0.5,0,0],[0.5,0.1,0],[0,0.2,0.4],[0,-0.2,-0.4]],
        'source_xyz':[[0,0,0],[10,1,0],[5,2,4],[5,-2,-4]],'types':['A','B','C','D'],
        'classes':['ol_intrinsic','cb_intrinsic','visual_projection','ol_sensory'],'sides':['L','R','M','?'],
        'degree_in':[2,5,1,1],'degree_out':[9,3,1,2],'edges':[[0,1,0.2],[2,0,-0.4],[2,3,0.1]],'candidate_count':4}
    verify(panel.load_view(view) and panel.points.size()==4,'Viewer accepts bounded anatomical metadata')
    var before: PackedVector2Array=panel.points.duplicate()
    game.playing=true
    game.player.active=true
    game.director.running=true
    game.director.action='lights'
    game.director.connected=true
    game.director.neural={'view_activity':[0.1,-0.9,0.4,0.2],'output':[0.1,-0.2,0.1,0.01],'mean_abs':0.02}
    game.director.last_neural_time=game.director.now()
    panel._process(0.1)
    verify(panel.history.size()==1 and 'CANLI' in panel.status_text(),'New measured sample updates history and live status')
    panel._process(0.1)
    verify(panel.history.size()==1,'Rendering does not invent neural samples')
    game.director.connected=false
    game.toggle_brain_details()
    game.director.connected=true
    verify(panel.expanded and not game.player.active and not game.director.running and not game.menu.visible,'V opens an interactive paused inspector')
    verify('DURAKLATILDI' in panel.status_text() and panel.snapshot.view_activity[1]==-0.9 and panel.measured_action=='lights','Paused view explicitly keeps the last measured activity and action')
    var anchor: Vector2=panel.graph_rect().get_center()
    var mouse=InputEventMouseButton.new()
    mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.position=anchor
    panel._gui_input(mouse)
    var motion=InputEventMouseMotion.new()
    motion.position=anchor+Vector2(40,20);motion.relative=Vector2(40,20)
    panel._gui_input(motion)
    mouse.pressed=false;mouse.position=motion.position;panel._gui_input(mouse)
    verify(panel.yaw>0.18 and panel.pitch> -0.12,'Mouse drag rotates actual 3D soma coordinates')
    var before_release: float=panel.yaw
    mouse.pressed=true;mouse.position=anchor;panel._gui_input(mouse)
    mouse.pressed=false;mouse.position=anchor+Vector2(20,0);panel._gui_input(mouse)
    verify(panel.yaw>before_release and panel.selected==-1,'A coalesced drag remains rotation instead of an accidental neuron click')
    var projected: PackedVector2Array=panel.points.duplicate()
    mouse.button_index=MOUSE_BUTTON_WHEEL_UP;mouse.pressed=true;mouse.position=anchor
    panel._gui_input(mouse)
    verify(panel.zoom>1 and panel.points!=projected,'Mouse wheel zooms the projected network')
    panel.reset_view()
    panel.select_at(panel.points[1])
    verify(panel.selected==1 and panel.metadata.types[panel.selected]=='B','Click selection resolves the biological record')
    panel.select_peak()
    verify(panel.selected==1,'Peak selection uses measured absolute activity')
    panel.group_choice.select(3)
    panel.select_peak()
    verify(panel.selected==2 and not panel.included(1),'Group filter constrains neuron selection')
    panel.group_choice.select(0)
    panel.reset_view()
    verify(panel.zoom==1 and is_equal_approx(panel.yaw,0.18),'Reset restores the initial camera')
    game.director.connected=false
    verify('BAĞLANTI YOK' in panel.status_text(),'Disconnect never presents retained samples as live')
    game.toggle_brain_details()
    verify(not panel.expanded and game.player.active and game.director.running and panel.points==before,'V returns to the original play state and compact projection')
    game.pause_game()
    panel.visible=false
    game.toggle_brain_details(); game.toggle_brain_details()
    verify(not game.player.active and game.menu.visible and not panel.visible,'Inspector preserves an already paused session and hidden compact panel')
    game.toggle_brain_details()
    var key=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_ESCAPE
    game._unhandled_input(key)
    verify(not panel.expanded and game.menu.visible and not game.player.active,'Escape closes inspection into the pause menu')
    game.director.round_id='next-fixture-round'
    game.director.last_neural_time=-1;game.director.neural={}
    panel._process(0.1)
    verify(panel.history.is_empty() and panel.snapshot.is_empty(),'A new round clears previous activity history')
    var invalid=view.duplicate(true);invalid.edges=[[0,100,1]]
    verify(not panel.load_view(invalid) and panel.points.is_empty(),'Invalid edge indices stop drawing safely')
    invalid=view.duplicate(true);invalid.xyz[0][0]=NAN
    verify(not panel.load_view(invalid),'Non-finite soma coordinates are rejected')
    invalid=view.duplicate(true);invalid.xyz[0][0]=1e100
    verify(not panel.load_view(invalid),'Oversized normalized coordinates cannot overflow the projection')
    invalid=view.duplicate(true);invalid.types=[]
    verify(not panel.load_view(invalid),'Misaligned metadata cannot select the wrong neuron')
    await game.quit_game(0 if failures.is_empty() else 1)
