"""Redraw the settings design from the supplied reference; no reference raster edits."""
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image, ImageFont

import render_sketches as base

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
BRAND_SVG = PROJECT / 'docs/design/settrace-brand-final/logo/settrace-symbol.svg'
BRAND_PNG = PROJECT / 'assets/brand/settrace-symbol.png'
PRESERVED = ['02-export-and-dark.png', '02-export-and-dark.svg',
             '03-support-states.png', '03-support-states.svg']


class Settings:
    def __init__(self, canvas, x=0, y=0):
        self.c, self.x, self.y, self.t = canvas, x, y, base.LIGHT
    rect = base.Phone.rect
    line = base.Phone.line
    chevron = base.Phone.chevron

    def txt(self,x,y,text,size=16,color='text',bold=False,maxw=None):
        # Preserve the supplied reference's type proportions when mapped to 390 logical px.
        base.Phone.txt(self,x,y,text,round(size*1.1),color,bold,maxw)

    def circle(self, x, y, diameter, color='surface', stroke=None):
        self.rect(x, y, diameter, diameter, color, diameter/2, stroke)

    def wrap(self, x, y, text, size=16, color='text', width=310, line_height=25):
        font = ImageFont.truetype(base.REGULAR, round(size*1.1)*base.SCALE)
        lines, line = [], ''
        for char in text:
            if line and self.c.d.textlength(line+char, font=font)/base.SCALE > width:
                lines.append(line)
                line = ''
            line += char
        if line:
            lines.append(line)
        for i, line in enumerate(lines):
            self.txt(x, y+i*line_height, line, size, color, maxw=width)
        return len(lines)*line_height

    def radio(self, y, label, selected=False):
        self.circle(51, y+2, 17, 'surface', 'accent' if selected else 'border')
        if selected:
            self.circle(55, y+6, 9, 'accent')
        self.txt(98, y, label, 16)

    def toggle(self, y):
        self.rect(294, y, 52, 32, 'accent', 16)
        self.circle(319, y+4, 24, 'surface')

    def external(self, x, y):
        self.line([(x+13,y+9),(x+13,y+16),(x,y+16),(x,y+3),(x+7,y+3)], 'secondary', 1.7)
        self.line([(x+6,y+10),(x+16,y),(x+8,y),(x+16,y),(x+16,y+8)], 'secondary', 1.7)

    def brand(self, x, y, size=40):
        # Raster uses the official packaged asset; SVG embeds the official vector paths.
        im = Image.open(BRAND_PNG).convert('RGBA')
        im.thumbnail((int(size*base.SCALE), int(size*base.SCALE)), Image.Resampling.LANCZOS)
        self.c.im.paste(im, (round((self.x+x)*base.SCALE), round((self.y+y)*base.SCALE)), im)
        svg = ET.parse(BRAND_SVG).getroot()
        paths = ''.join(ET.tostring(e, encoding='unicode') for e in svg if e.tag.endswith('path'))
        self.c.svg.append(f'<g transform="translate({self.x+x} {self.y+y}) scale({size/100})" style="color:#153C34">{paths}</g>')

    def data(self, y):
        self.txt(24, y, '数据', 16, 'secondary')
        self.rect(24, y+32, 342, 192, 'surface', 16, 'line')
        self.txt(40, y+60, '备份与恢复', 16)
        self.txt(40, y+88, '完整备份、恢复与撤回', 16, 'secondary', maxw=270)
        self.chevron(337, y+77)
        self.line([(40,y+128),(350,y+128)], 'line', 1)
        self.txt(40, y+156, '诊断与日志', 16)
        self.txt(40, y+184, '导出诊断包，帮助排查问题', 16, 'secondary', maxw=270)
        self.chevron(337, y+173)

    def about(self, y):
        self.txt(24, y, '关于 SetTrace', 16, 'secondary')
        top = y+32
        self.rect(24, top, 342, 432, 'surface', 16, 'line')
        self.brand(36, top+14)
        self.txt(97, top+23, 'SetTrace', 24, bold=True)
        self.wrap(40, top+78, '轻量、离线的训练记录工具，专注每一组。', 16)
        self.txt(40, top+143, '版本 0.2.4 (10)', 16, 'secondary')
        self.line([(40,top+186),(350,top+186)], 'line', 1)
        for i, label in enumerate(['项目主页','问题反馈','隐私与数据说明','第三方开源许可']):
            yy = top+215+i*56
            self.txt(40, yy, label, 16)
            if i<2:
                self.external(334, yy+1)
            else:
                self.chevron(337, yy+3)

    def bottom_nav(self, y, viewport=False):
        self.rect(0, y, 390, 74 if viewport else 88, 'surface', 0)
        self.rect(255, y+8, 119, 60 if viewport else 68, 'soft', 13)
        for xx, label in [(72,'计划'),(194,'记录'),(315,'设置')]:
            col='onsoft' if label=='设置' else 'secondary'
            if label=='计划':
                self.rect(xx-8, y+19, 17, 17, 'surface', 1, col)
                self.line([(xx-4,y+22),(xx+5,y+22),(xx+5,y+25),(xx-4,y+25),(xx-4,y+31),(xx+5,y+31)], col, 1.3)
            elif label=='记录':
                self.circle(xx-8,y+19,17,'surface',col)
                self.line([(xx,y+22),(xx,y+28),(xx+4,y+31)],col,1.7)
                self.line([(xx-11,y+27),(xx-7,y+31),(xx-4,y+27)],col,1.6)
            else:
                points=[]
                import math
                for i in range(24):
                    a=i*math.pi/12
                    radius=10 if i%3!=1 else 7.5
                    points.append((xx+radius*math.cos(a), y+27+radius*math.sin(a)))
                self.line(points+[points[0]],col,1.6)
                self.circle(xx-3,y+24,6,'soft',col)
            self.txt(xx-16,y+48,label,14,col,label=='设置')
        if viewport:
            return
        self.rect(0, y+88, 390, 40, 'surface', 0)
        self.line([(106,y+105),(118,y+105)],'line',1)
        self.line([(106,y+109),(118,y+109)],'line',1)
        self.rect(191,y+101,11,11,'surface',3,'line')
        self.line([(279,y+101),(273,y+107),(279,y+113)],'line',1)


def full_page():
    c=base.Canvas(390,2368)
    c.rect(0,0,390,2368,base.LIGHT['bg'])
    s=Settings(c)
    s.txt(24,28,'设置',28,bold=True)
    s.txt(24,92,'外观',16,'secondary')
    s.rect(24,124,342,202,'surface',16,'line')
    for yy, label, on in [(162,'跟随系统',True),(219,'浅色',False),(276,'深色',False)]:
        s.radio(yy,label,on)
    s.txt(24,360,'主题色',16,'secondary')
    s.rect(24,391,342,126,'surface',16,'line')
    for xx,color in [(75,'#087F6B'),(155,'#245FC7'),(235,'#7046B8'),(315,'#303A43')]:
        s.circle(xx-18,418,36,color)
    s.circle(51,412,48,'surface','accent')
    s.circle(57,418,36,'accent')
    s.line([(67,436),(73,442),(84,430)],'on',2)
    s.txt(40,483,'点选即刻切换，自动保存',14,'secondary')
    s.txt(24,548,'语言',16,'secondary')
    s.rect(24,581,342,145,'surface',16,'line')
    s.radio(616,'English');s.radio(673,'中文',True)
    s.txt(24,758,'休息提醒',16,'secondary')
    s.rect(24,790,342,490,'surface',16,'line')
    s.txt(40,820,'休息结束提醒',16)
    s.txt(40,849,'已启用。休息结束后提醒，',16,'onsoft')
    s.txt(40,875,'确认后停止。',16,'onsoft');s.toggle(837)
    for yy in [909,998,1071,1181]:s.line([(40,yy),(350,yy)],'line',1)
    s.txt(40,932,'提示音',16);s.txt(40,960,'三音提示',16,'secondary')
    s.circle(282,945,19,'surface','secondary')
    s.line([(290,950),(295,954),(290,958),(290,950)],'secondary',1.6)
    s.chevron(337,949)
    s.txt(40,1021,'振动',16);s.toggle(1016)
    s.txt(40,1094,'重复提醒',16)
    s.txt(40,1122,'未确认时，按设定间隔再次',16,'secondary')
    s.txt(40,1148,'提醒',16,'secondary');s.toggle(1110)
    s.txt(40,1206,'提醒间隔',16);s.txt(40,1235,'每 10 秒',16,'secondary');s.chevron(337,1219)
    s.wrap(24,1298,'点击通知返回训练，或点击“知道了”停止本次提醒。',16,'secondary',342,25)
    s.txt(24,1356,'声音与振动遵循系统设置。',16,'secondary')
    s.txt(24,1381,'后台提醒间隔可能受系统调度影响。',16,'secondary',maxw=342)
    s.data(1425)
    s.about(1682)
    s.wrap(24,2171,'数据保存在本机。请导出完整备份以长期保留已保存训练。',12,'secondary',342,21)
    s.bottom_nav(2240)
    c.save('00-settings-latest-full')
    return c


def focus_board():
    c=base.Canvas(1040,1138)
    c.text(40,28,'SETTRACE  /  设置页修订',14,'#076D5C',True)
    c.text(40,60,'沿用最新设置，只增加一行诊断入口',28,bold=True)
    c.text(40,107,'完整设置保留原顺序；下图为数据与关于分区局部，非固定高度单屏。',14,'#586970')
    c.text(40,159,'L00  设置 · 入口局部放大',18,bold=True)
    # Native UI redraw at 1:1 logical size, with all about content readable.
    c.rect(40,198,390,828,base.LIGHT['bg'],20,'#AAB8B2')
    s=Settings(c,40,198)
    s.data(24)
    s.about(280)
    s.wrap(24,770,'数据保存在本机。请导出完整备份以长期保留已保存训练。',12,'secondary',342,21)
    # Avoid suggesting that the long, scrollable local excerpt has fixed navigation.
    c.text(40,1048,'局部内容随页面滚动；底部导航仍固定。',13,'#586970',maxw=390)
    c.text(505,208,'本次唯一新增',14,'#076D5C',True)
    c.text(505,245,'诊断与日志',26,bold=True)
    c.text(505,290,'导出诊断包，帮助排查问题',16,'#586970')
    c.line([(420,388),(470,388),(470,323),(505,323)],'#087F6B',1.5)
    c.text(505,371,'与备份入口同层级',18,bold=True)
    for y,line in [(412,'同一卡片、相同文字样式和右箭头。'),(443,'点击进入此前认可的诊断与日志主页。'),(474,'不在设置首页直接放导出或清空按钮。')]:
        c.text(505,y,line,15,'#586970',maxw=490)
    c.text(505,548,'保留最新设置的完整内容',18,bold=True)
    for i,line in enumerate(['外观三选一与四种主题色','English / 中文语言选择','提示音及试听、振动、重复提醒与间隔','备份与恢复入口','正式品牌、版本和关于中的全部链接','计划 / 记录 / 设置底部导航']):
        c.text(505,594+i*40,line,15,'#586970',maxw=490)
    c.text(505,901,'其他诊断页面沿用上一版设计。',16,'#076D5C',True)
    c.text(40,1096,'设计草图 · 以本次提供的最新设置截图为依据 · 未修改 APP 功能代码',12,'#586970')
    c.save('00-settings-latest-focus')
    return c


def latest_settings_view(p):
    # Scrolled viewport: the bottom of About continues underneath the scroll edge.
    s=Settings(p.c,p.x,p.y)
    s.data(56)
    s.about(312)
    # The opaque fixed nav masks the continuing scrollable content.
    s.bottom_nav(742,viewport=True)
    # Use the original phone's gesture indicator; status/navigation bars are schematic.
    p.rect(1,816,388,24,'surface',0)
    p.rect(145,827,100,4,'text',2)


def update_main_board():
    c=base.board('从最新设置进入，继续原有导出流程','01 / 修订设置入口 · 诊断主页与导出说明保持原设计')
    for x,code,title,fn,note in [
        (40,'L00','设置 · 滚动到数据',latest_settings_view,('按最新截图保留数据与关于卡片样式。','完整外观、语言与提醒设置另见长图。')),
        (485,'L01','诊断与日志',base.home,('优先展示保存范围与容量，底部固定导出。','详细诊断与清理为次要操作。')),
        (930,'L02','导出前说明',base.preview,('范围、位置、包含内容与隐私一次说清。','点击保存后才执行真实文件操作。'))]:
        base.caption(c,x,code,title,note);fn(base.Phone(c,x))
    c.save('01-main-flow')
    return c


def digest(name):
    return hashlib.sha256((ROOT/name).read_bytes()).hexdigest()


def main():
    before={name:digest(name) for name in PRESERVED}
    old=Image.open(ROOT/'01-main-flow.png').convert('RGB')
    # The full phone areas of L01 and L02 must remain pixel-identical.
    accepted={name:old.crop((x*2,176*2,(x+390)*2,1020*2)).tobytes()
              for name,x in [('L01',485),('L02',930)]}
    canvases=[full_page(),focus_board(),update_main_board()]
    new=Image.open(ROOT/'01-main-flow.png').convert('RGB')
    unchanged_phones={name:new.crop((x*2,176*2,(x+390)*2,1020*2)).tobytes()==accepted[name]
                      for name,x in [('L01',485),('L02',930)]}
    preserved={name:digest(name)==before[name] for name in PRESERVED}
    report={'reference':'User-provided latest settings screenshot, codex-clipboard-f5e23dd3-ab08-4a69-ac04-b8a727e18023.png',
            'text_width_overflows':[entry for c in canvases for entry in c.overflows],
            'accepted_phone_pixels_unchanged':unchanged_phones,
            'accepted_other_boards_unchanged':preserved,
            'preserved_sha256':before,
            'scope':'Static native UI redraw only; reference raster was read, never modified; no application changes.'}
    (ROOT/'settings-revision-checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False))


if __name__=='__main__':
    main()
