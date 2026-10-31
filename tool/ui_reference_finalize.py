"""Finalize capture registration and narrow factual documentation corrections."""
import os
import shutil
from ui_reference import ROOT,RUN,CURRENT,load,dump,write,sha,safe
from ui_reference_publish import rectify_release_rows

def main():
    rows=rectify_release_rows(load(RUN/'release-captures.json'))
    retained=[]
    for row in rows:
        if row['capture_id']=='B05a-system-file-picker-zh-dark-360-s1':
            # Pixels already show the system picker, but the hierarchy was read
            # before its window transition. Preserve it outside the final atlas.
            rejected=RUN/'rejected-frames'
            for field in ['path','ui_tree']:
                source=safe(CURRENT/row[field]);target=safe(rejected/source.name)
                if source.exists():shutil.move(str(source),str(target))
            dump(RUN/'rejected-picker-registration.json',{'capture':row,'reason':'pre-transition hierarchy differs from PNG window; replaced with stable system-picker capture; original bytes retained'})
            continue
        correction=row.get('registration_correction')
        if correction and 'original_capture_id' not in correction:
            correction['original_capture_id']=row['capture_id'];correction['original_path']=row['path']
            key=f"{row['screen_id']}-{row['state_id']}-{row['language']}-{row['theme']}-360-s1-registration-corrected"
            group='backup' if row['screen_id']=='B16' else 'workout'
            for field,destination in [('path',f'screenshots/{group}/{key}.png'),('ui_tree',f'verification/ui-trees/{key}.json')]:
                source=safe(CURRENT/row[field]);target=safe(CURRENT/destination)
                target.parent.mkdir(parents=True,exist_ok=True)
                assert not target.exists(),target
                shutil.move(str(source),str(target));row[field]=destination
            row['capture_id']=key;row['group']=group
            assert sha(CURRENT/row['path'])==row['sha256']
        retained.append(row)
    dump(RUN/'release-captures.json',retained)
    p=CURRENT/'specs/features/diagnostics.md';text=p.read_text(encoding='utf-8')
    text=text.replace('存储预算分配、日志字段、写入器及异常捕获机制仍属于后续日志技术设计。','存储预算、日志字段、写入器及异常捕获机制已接入现有实现；具体技术依据见现行 app-diagnostics 主规格与既有实施验收。')
    text=text.replace('也不表示业务主规格已更新。','业务主规格同步与归档已于2026-10-25完成，人工与设备待验仍按原范围保留。')
    text=text.replace('设置入口以最新完整设置长截图为依据，确认后的完整长图优先用于 L00 呈现；其余已确认诊断页面保持原稿。早期简化设置片段不再作为设置布局依据。',
       '当前设置入口以本次 C01 四组合完整滚动原帧为参考（见当前图册），L00 与 B00 共用其中的数据分区。下面的草图名称仅说明历史设计来源，早期简化片段不作为当前实装画面。')
    write(p,text)
    p=CURRENT/'specs/features/backup.md';text=p.read_text(encoding='utf-8').replace('均待实现后验证。','以现有独立验收与本次 results.json 的实际范围分别登记；未做条件继续待验。')
    write(p,text)

if __name__=='__main__':main()
