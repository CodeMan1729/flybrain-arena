extends SceneTree

# Diagnostic values test layout only; they are not reported as biological measurements.
func _initialize() -> void:
    check_layout.call_deferred()

func check_layout() -> void:
    var args := OS.get_cmdline_user_args()
    var fullscreen: bool='--fullscreen-check' in args
    DisplayServer.window_set_size(Vector2i(1920,1080))
    var game=load('res://main.tscn').instantiate()
    game.settings_path=''
    for arg in args:
        if arg.begins_with('--saved-fullscreen-check='):
            game.settings_path=arg.trim_prefix('--saved-fullscreen-check=')
    var reopening: bool=not game.settings_path.is_empty() and FileAccess.file_exists(game.settings_path)
    var saved_settings := FileAccess.get_file_as_bytes(game.settings_path) if reopening else PackedByteArray()
    root.add_child(game)
    game.director.set_process(false)
    var startup_ok: bool=not reopening or (game.fullscreen and game.volume==0)
    game.set_volume(0)
    game.ambience.stop()
    game.ambience.stream=null
    if not game.settings_path.is_empty():
        if not reopening:
            await create_timer(1).timeout
            game.toggle_fullscreen() # First process saves through the real menu path; the second loads it in _ready.
        await create_timer(2).timeout
        startup_ok=startup_ok and game.fullscreen and DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
        var stored := ConfigFile.new()
        startup_ok=startup_ok and stored.load(game.settings_path)==OK
        startup_ok=startup_ok and stored.get_value('settings','fullscreen',false)==true and stored.get_value('settings','volume',-1)==0
        startup_ok=startup_ok and AudioServer.is_bus_mute(0)
        for label in game.menu.find_children('*','Label',true,false):
            if label.is_visible_in_tree():
                startup_ok=startup_ok and game.get_viewport().get_visible_rect().encloses(label.get_global_rect())
                startup_ok=startup_ok and label.get_visible_line_count()==label.get_line_count()
        startup_ok=startup_ok and game.start_button.is_visible_in_tree() and game.start_button.text=='BAŞLAT'
        startup_ok=startup_ok and ('bağlanılıyor' in game.memory_text.text)
        if reopening: startup_ok=startup_ok and FileAccess.get_file_as_bytes(game.settings_path)==saved_settings
        print(('PASS: ' if startup_ok else 'FAIL: ')+('Saved fullscreen cold start' if reopening else 'Fullscreen preference saved')+'; menu text fits and mute is retained')
        if DisplayServer.get_name()!='headless':
            await RenderingServer.frame_post_draw
            startup_ok=game.get_viewport().get_texture().get_image().save_png(game.settings_path+'-menu.png')==OK and startup_ok
    game._process(0.1)
    var memory_ok: bool='bağlanılıyor' in game.memory_text.text and not '0' in game.memory_text.text
    game.director.connected=true
    game.director.memory={'rounds':0,'updates':0,'prior_events':8640}
    game._process(0.1)
    memory_ok=memory_ok and '0 kişisel öğrenme örneği' in game.memory_text.text and '8640' in game.memory_text.text
    game.director.memory.updates=27
    game.director.connected=false
    game._process(0.1)
    memory_ok=memory_ok and '27 kişisel öğrenme örneği' in game.memory_text.text and 'Son alınan kayıt' in game.memory_text.text
    game.director.memory.updates=28
    game.director.connected=true
    game._process(0.1)
    memory_ok=memory_ok and '28 kişisel öğrenme örneği' in game.memory_text.text and not 'Son alınan kayıt' in game.memory_text.text
    print(('PASS: ' if memory_ok else 'FAIL: ')+'Learning display distinguishes unavailable, real zero, retained offline and refreshed data')
    var menu_ok := true
    for phase in ['initial','paused','won','lost']:
        game.playing=phase!='initial'
        game.completed=phase in ['won','lost']
        game.round_outcome=phase if game.completed else ''
        game.elapsed=42
        game.start_button.text={'initial':'BAŞLAT','paused':'DEVAM ET','won':'YENİ TUR','lost':'YENİ TUR'}[phase]
        # Reproduce the stale title observed after a web reconnect; game state and connection are current.
        game.menu_title.text="Beyne bağlanılıyor… Hazır olunca Başlat'a bas."
        for connected in [false,true]:
            game.director.connected=connected
            game.director.reason='Gerçek bağlantı verisi hazır' if connected else 'Bağlantı kesildi · güvenli bekleme'
            game._process(0.1)
            var expected: String={"initial":"Drone'u vur. Temastan kaçın.",'paused':'DURAKLATILDI · Arena bekler.','won':'KAZANDIN · Drone etkisiz.','lost':'KAYBETTİN · Drone temas etti.' }[phase]
            menu_ok=menu_ok and game.menu_title.text==expected and game.director.reason in game.notice.text
            menu_ok=menu_ok and not game.player.active and not game.director.running and game.menu.visible
    print(('PASS: ' if menu_ok else 'FAIL: ')+'Menu title follows game phase, connection status refreshes separately, and reconnect never resumes play')
    game.playing=false
    game.completed=false
    game.elapsed=0
    game.director.connected=false
    game.hud.visible=true
    game.menu.visible=false
    game.debug_panel.visible=true
    game.director.neural={'output':[-0.1234,0.2345,-0.3456,0.4567], 'active_neurons':166700,
        'mean_abs':0.1234,'rss_mb':1234.5,'latency_ms':1234.5}
    game.director.updates=123456789
    game.director.reason='Ortak öğrenme belleği oyuncular tarafından sıfırlanamaz'
    game._process(0.1)
    game.hud.add_child(game.ui_label('YERLEŞİM TESTİ / YAPAY SAYILAR',20))
    if fullscreen:
        await create_timer(1).timeout
        game.toggle_fullscreen()
    await create_timer(0.5 if DisplayServer.get_name()=='headless' else 2.0).timeout # Let the native fullscreen transition and font atlas finish.
    await process_frame
    await process_frame
    var rect: Rect2=game.debug_panel.get_global_rect()
    print('HUD bounds: ',rect,' / viewport: ',game.get_viewport().get_visible_rect())
    print('HUD minimum: ',game.debug_text.get_minimum_size(),' / label: ',game.debug_text.size)
    var passed: bool=game.get_viewport().get_visible_rect().encloses(rect) and rect.end.y<=game.brain_view.position.y
    passed=passed and game.debug_text.get_visible_line_count()==game.debug_text.get_line_count()
    for text in [game.director.reason,'123456789','166700','1234.5','-0.1234','0.4567']:
        passed=passed and text in game.debug_text.text
    print(('PASS: ' if passed else 'FAIL: ')+'Every diagnostic value is visible, inside the screen, above the brain view')
    if DisplayServer.get_name()!='headless':
        await RenderingServer.frame_post_draw
        var screenshot_path: String=game.settings_path+'-hud.png' if not game.settings_path.is_empty() else 'res://../reports/hud-'+('fullscreen' if fullscreen else '1080p')+'.png'
        passed=game.get_viewport().get_texture().get_image().save_png(screenshot_path)==OK and passed
        if fullscreen:
            passed=passed and DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
            print(('PASS: ' if passed else 'FAIL: ')+'Native fullscreen mode is active')
    await game.quit_game(0 if passed and memory_ok and startup_ok and menu_ok else 1)
