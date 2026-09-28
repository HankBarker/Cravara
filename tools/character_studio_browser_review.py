"""Exercise the real local Studio player without changing user approvals."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright

OUT=Path(__file__).resolve().parents[1]/'art/character-studio/raptor-v2/batch-review-r2/browser-review'
OUT.mkdir(exist_ok=True)
with sync_playwright() as p:
    browser=p.chromium.launch(channel='msedge',headless=True)
    page=browser.new_page(viewport={'width':1400,'height':1050},device_scale_factor=1)
    errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto('http://127.0.0.1:18765/')
    page.wait_for_function("document.querySelector('#clip').options.length===21")
    keys=page.locator('#clip option').evaluate_all('(els)=>els.map(e=>e.value)')
    results=[]
    for key in keys:
        page.select_option('#clip',key)
        page.locator('.panel.anim').scroll_into_view_if_needed()
        page.wait_for_function("Array.from(document.querySelectorAll('#frames img')).every(i=>i.complete&&i.naturalWidth>0)")
        count=page.locator('#frames button').count()
        fps=int(page.input_value('#fps'))
        page.click('#play')
        page.wait_for_timeout((count/fps+0.15)*1000)
        status=page.locator('#frameNumber').inner_text()
        oneshot=key.startswith(('bite','swipe','death'))
        if oneshot:
            assert status.startswith(f'{count}/{count}'),(key,status)
            page.wait_for_timeout(160)
            assert page.locator('#frameNumber').inner_text()==status
            page.click('#play')
            page.wait_for_timeout(70)
            assert not page.locator('#frameNumber').inner_text().startswith(f'{count}/{count}')
        # Slow playback check, then inspect every individual scrubbed image.
        page.select_option('#clip',key)
        page.fill('#fps',str(max(2,fps//2)))
        page.click('#play');page.wait_for_timeout(300);page.click('#play')
        for i in range(count):
            page.locator('#frames button').nth(i).click()
            page.wait_for_function("document.querySelector('#frame').complete&&document.querySelector('#frame').naturalWidth>0")
            assert page.locator('#frameNumber').inner_text().startswith(f'{i+1}/{count}')
        page.select_option('#clip',key)
        page.locator('#frames button').nth(min(5,count-1)).click()
        page.locator('.panel.anim').screenshot(path=str(OUT/f'{key}.png'))
        results.append({'clip':key,'frames':count,'fps':fps,'normal_playback':True,'half_speed':True,'all_frames_loaded':True,'one_shot_hold':oneshot})
        print('REVIEWED',key,flush=True)
    assert not errors,errors
    (OUT/'results.json').write_text(json.dumps({'clips':results,'page_errors':errors},indent=2))
    browser.close()
