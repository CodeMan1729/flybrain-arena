extends SceneTree

# Diagnostic values test layout only; they are not reported as biological measurements.
func _initialize() -> void:
    check_layout.call_deferred()

func check_layout() -> void:
    var fullscreen: bool='--fullscreen-check' in OS.get_cmdline_user_args()
    DisplayServer.window_set_size(Vector2i(1920,1080))
    var game=load('res://main.tscn').instantiate()
    game.settings_path=''
    root.add_child(game)
    game.director.set_process(false)
    game.set_volume(0)
    game.ambience.stop()
    game.ambience.stream=null
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
        passed=game.get_viewport().get_texture().get_image().save_png('res://../reports/hud-'+('fullscreen' if fullscreen else '1080p')+'.png')==OK and passed
        if fullscreen:
            passed=passed and DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
            print(('PASS: ' if passed else 'FAIL: ')+'Native fullscreen mode is active')
    await game.quit_game(0 if passed and memory_ok else 1)
