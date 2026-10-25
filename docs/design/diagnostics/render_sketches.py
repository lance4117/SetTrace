"""Render original UI design sketches; does not modify application sources."""
from pathlib import Path
import html
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
SCALE = 2
REGULAR = 'C:/Windows/Fonts/msyh.ttc'
BOLD = 'C:/Windows/Fonts/msyhbd.ttc'
LIGHT = dict(bg='#F5F7F8', surface='#FFFFFF', text='#19262C', secondary='#586970',
             line='#DBE3E5', border='#71858C', accent='#087F6B', on='#FFFFFF',
             soft='#E2F2ED', onsoft='#076D5C', warning='#855208', warnbg='#FFF1D8',
             danger='#B13C35', dangerbg='#FFF0EE', disabled='#E5E9EB', disabledtext='#63747B')
DARK = dict(bg='#111518', surface='#191E22', text='#F0F5F6', secondary='#ABB9BF',
            line='#354047', border='#82969D', accent='#5DD9B6', on='#102A22',
            soft='#203B35', onsoft='#5DD9B6', warning='#F0CA83', warnbg='#3E3322',
            danger='#FFB4AB', dangerbg='#422923', disabled='#2C353B', disabledtext='#A3B0B6')

class Canvas:
    def __init__(self, width=1360, height=1138):
        self.w, self.h = width, height
        self.im = Image.new('RGB', (width*SCALE, height*SCALE), '#E9EEEC')
        self.d = ImageDraw.Draw(self.im)
        self.svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<rect width="100%" height="100%" fill="#E9EEEC"/>']
        self.overflows = []
    def rect(self,x,y,w,h,fill,r=0,stroke=None,sw=1):
        box=tuple(round(v*SCALE) for v in (x,y,x+w,y+h))
        self.d.rounded_rectangle(box, radius=round(r*SCALE), fill=fill, outline=stroke, width=max(1,round(sw*SCALE)))
        self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke or "none"}" stroke-width="{sw}"/>')
    def line(self,points,color,width=1.7):
        self.d.line([(round(x*SCALE),round(y*SCALE)) for x,y in points],fill=color,width=round(width*SCALE),joint='curve')
        pts=' '.join(f'{x},{y}' for x,y in points)
        self.svg.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>')
    def text(self,x,y,value,size=16,color='#19262C',bold=False,maxw=None):
        font=ImageFont.truetype(BOLD if bold else REGULAR,round(size*SCALE))
        length=self.d.textlength(value,font=font)/SCALE
        if maxw is not None and length>maxw+0.5:
            self.overflows.append(dict(text=value,width=round(length,2),available=maxw))
        self.d.text((round(x*SCALE),round(y*SCALE)),value,font=font,fill=color,anchor='lt')
        self.svg.append(f'<text x="{x}" y="{y}" font-family="Microsoft YaHei, sans-serif" font-size="{size}" font-weight="{700 if bold else 400}" dominant-baseline="text-before-edge" fill="{color}">{html.escape(value)}</text>')
        return length
    def save(self,name):
        self.im.save(ROOT/f'{name}.png')
        (ROOT/f'{name}.svg').write_text('\n'.join(self.svg+['</svg>']),encoding='utf-8')

class Phone:
    def __init__(self,c,x,y=176,dark=False):
        self.c,self.x,self.y,self.t=c,x,y,DARK if dark else LIGHT
        c.rect(x,y,390,844,self.t['bg'],28,'#AAB8B2',1)
        self.txt(24,15,'9:41',12,bold=True)
        self.line([(320,28),(320,22),(324,22),(324,28),(328,28),(328,18),(332,18),(332,28)],'secondary',1.5)
        self.rect(343,19,22,11,'bg',3,'secondary');self.rect(346,22,15,5,'secondary',1)
        self.line([(368,23),(368,26)],'secondary',1.5)
        self.rect(145,827,100,4,'text',2)
    def rect(self,x,y,w,h,color='surface',r=16,stroke=None):
        self.c.rect(self.x+x,self.y+y,w,h,self.t.get(color,color),r,self.t.get(stroke,stroke))
    def txt(self,x,y,s,size=16,color='text',bold=False,maxw=None):
        self.c.text(self.x+x,self.y+y,s,size,self.t.get(color,color),bold,maxw)
    def line(self,points,color='line',width=1.7):
        self.c.line([(self.x+x,self.y+y) for x,y in points],self.t.get(color,color),width)
    def chevron(self,x,y,down=False):
        self.line([(x,y),(x+5,y+5),(x+(10 if down else 0),y+10)],'secondary')
    def header(self,title):
        self.line([(35,60),(25,70),(35,80)],'text',2)
        self.line([(25,70),(46,70)],'text',2)
        self.txt(64,57,title,18,bold=True,maxw=300)
    def button(self,y,label,kind='primary',x=24,w=342):
        bg,fg={'primary':('accent','on'),'secondary':('soft','onsoft'),'outline':('surface','text'),'disabled':('disabled','disabledtext'),'danger':('danger','on')}[kind]
        self.rect(x,y,w,56,bg,14,'border' if kind=='outline' else None)
        font=ImageFont.truetype(BOLD,16*SCALE)
        textw=self.c.d.textlength(label,font=font)/SCALE
        self.txt(x+(w-textw)/2,y+17,label,16,fg,True,maxw=w-24)
    def footer(self,label,note='',kind='primary'):
        self.rect(1,713,388,107,'bg',0)
        self.line([(24,713),(366,713)],'line',1)
        self.button(729,label,kind)
        if note:
            self.txt(24,797,note,12,'secondary',maxw=342)
    def switch(self,x,y,on=True):
        self.rect(x,y,48,28,'accent' if on else 'border',14)
        self.rect(x+(23 if on else 3),y+3,22,22,'on' if on else 'surface',11)
        if on:self.line([(x+29,y+14),(x+33,y+18),(x+39,y+10)],'accent',1.8)
    def check(self,x,y,color='accent'):
        self.line([(x,y+7),(x+5,y+12),(x+14,y)],color,2.5)
    def badge(self,x,y,label,color='soft',fg='onsoft'):
        self.rect(x,y,68,26,color,13);self.txt(x+12,y+5,label,12,fg)
    def nav(self):
        self.rect(1,742,388,74,'surface',0);self.line([(1,742),(389,742)],'line',1)
        for x,label in [(60,'计划'),(183,'记录'),(305,'设置')]:
            if label=='设置':self.rect(x-12,751,54,28,'soft',14)
            if label=='计划':
                self.rect(x+5,756,19,19,'surface',3,'secondary')
                for yy in [761,766,771]:self.line([(x+9,yy),(x+20,yy)],'secondary',1.3)
            elif label=='记录':
                self.rect(x+5,756,20,20,'surface',10,'secondary')
                self.line([(x+15,759),(x+15,766),(x+20,769)],'secondary',1.5)
            else:
                self.rect(x+5,756,20,20,'soft',10,'onsoft')
                self.rect(x+11,762,8,8,'soft',4,'onsoft')
                for dx,dy in [(0,-13),(0,13),(-13,0),(13,0)]:
                    self.line([(x+15+dx*.76,766+dy*.76),(x+15+dx,766+dy)],'onsoft',2)
            self.txt(x,786,label,12,'secondary' if label!='设置' else 'onsoft',label=='设置')

def caption(c,x,code,title,note):
    c.text(x,128,code,12,'#076D5C',True)
    c.text(x+44,124,title,19,bold=True)
    c.text(x,1044,note[0],14,'#586970',maxw=390)
    c.text(x,1068,note[1],14,'#586970',maxw=390)

def board(title,subtitle):
    c=Canvas();c.text(40,28,'SETTRACE  /  诊断与日志',14,'#076D5C',True)
    c.text(40,56,title,30,bold=True)
    c.text(40,99,subtitle,14,'#586970')
    c.text(40,1108,'界面草图 · 数值与结果均为设计示例 · 未接入真实日志或文件操作',12,'#586970')
    return c

def home(p):
    p.header('诊断与日志')
    p.txt(24,113,'遇到问题时，导出诊断包帮助排查。',16,maxw=342)
    p.rect(24,157,342,105)
    p.txt(40,177,'本机诊断记录',16,bold=True);p.switch(302,174)
    p.txt(40,213,'仅保存在此设备，不自动上传。',14,'secondary',maxw=268)
    p.rect(24,278,342,210)
    p.txt(40,297,'已保存的日志',16,bold=True);p.badge(282,293,'记录中')
    p.txt(40,336,'10月17日 09:40 — 10月23日 15:30',14,'secondary',maxw=310)
    p.txt(40,369,'3.8',30,bold=True);p.txt(101,383,'MiB / 20 MiB',14,'secondary')
    p.rect(40,418,310,5,'line',2);p.rect(40,418,59,5,'accent',2)
    p.txt(40,441,'最多保留7天或20 MiB，先到先清理。',14,'secondary',maxw=310)
    p.rect(24,504,342,72)
    p.txt(40,520,'临时详细诊断',16);p.txt(40,547,'按需开启，30分钟后自动关闭',12,'secondary')
    p.txt(298,529,'关闭',14,'secondary');p.chevron(346,529)
    p.txt(40,605,'记录与隐私说明',16);p.chevron(346,606)
    p.txt(40,665,'清空本机日志',16,'danger')
    p.footer('导出诊断包','仅保存文件，不会自动发送。')

def settings(p):
    from render_settings_revision import latest_settings_view
    latest_settings_view(p)

def preview(p):
    p.header('导出诊断包')
    p.txt(24,117,'把问题线索保存下来',24,bold=True)
    p.txt(24,159,'导出后，可自行将文件发给开发者。',16,maxw=342)
    p.rect(24,206,342,140)
    p.txt(40,224,'本次导出',16,bold=True)
    p.txt(40,263,'日志范围',14,'secondary');p.txt(131,263,'10月17日 — 10月23日',14)
    p.txt(40,297,'保存位置',14,'secondary');p.txt(131,297,'系统下载目录 / Download',14,maxw=220)
    p.txt(24,376,'包含哪些信息',16,bold=True)
    for y,label in [(419,'应用与系统版本、相关权限状态'),(461,'关键操作经过、错误与诊断信息')]:
        p.check(27,y+1);p.txt(53,y,label,16,maxw=313)
    p.rect(24,514,342,136,'soft')
    p.txt(40,532,'分享前请了解',16,'onsoft',True)
    p.txt(40,568,'不含计划名、动作名或完整训练记录。',14,'onsoft',maxw=310)
    p.txt(40,596,'仍可能反映使用时间与操作习惯，',14,'onsoft',maxw=310)
    p.txt(40,620,'请仅分享给你信任的人。',14,'onsoft')
    p.footer('保存到下载目录','ZIP 文件 · 不会自动上传')

def progress(p):
    p.header('导出诊断包')
    p.rect(24,133,342,91,'soft');p.txt(40,151,'正在准备诊断包',22,'onsoft',True)
    p.txt(40,189,'正在打包现有日志…',14,'onsoft')
    p.txt(24,258,'处理进度',16,bold=True)
    for y,num,label,detail,done,active in [
        (310,'1','固定导出范围','已完成',True,False),
        (396,'2','打包日志与设备信息','正在处理',False,True),
        (482,'3','保存并核验文件','等待处理',False,False)]:
        p.rect(24,y,30,30,'soft' if done or active else 'line',15)
        if done:p.check(32,y+8)
        else:p.txt(34,y+5,num,14,'onsoft' if active else 'secondary',True)
        p.txt(70,y-1,label,16,bold=active);p.txt(70,y+29,detail,14,'secondary')
        if y<482:p.line([(39,y+39),(39,y+76)],'line',1.5)
    p.txt(24,595,'训练和休息计时会继续。',16)
    p.txt(24,629,'取消将清理本次未完成的导出文件。',14,'secondary',maxw=342)
    p.footer('取消导出','完成后可在下载目录找到文件。','outline')

def success(p):
    p.header('导出诊断包')
    p.rect(24,133,56,56,'soft',28);p.check(43,152)
    p.txt(24,213,'诊断包已保存',24,bold=True)
    p.txt(24,259,'可以将这个文件发给开发者帮助排查。',16,maxw=342)
    p.rect(24,309,342,220)
    p.txt(40,330,'文件',14,'secondary')
    p.txt(40,361,'SetTrace-diagnostics-',16,bold=True)
    p.txt(40,390,'20261023-153000-AB12.zip',16,bold=True,maxw=310)
    p.line([(40,430),(350,430)],'line',1)
    p.txt(40,452,'位置',14,'secondary');p.txt(115,452,'Download',14)
    p.txt(40,487,'大小',14,'secondary');p.txt(115,487,'1.2 MiB',14)
    p.txt(24,564,'可在系统文件管理器的下载目录找到。',14,'secondary',maxw=342)
    p.txt(24,603,'文件不会自动发送，也不会自动更新。',14,'secondary',maxw=342)
    p.footer('完成','已导出的文件由你自行保管。')

def detail(p):
    p.header('诊断与日志')
    p.txt(24,119,'临时详细诊断',24,bold=True)
    p.txt(24,164,'复现问题时，临时记录更多技术细节。',16,maxw=342)
    p.rect(24,216,342,96)
    p.txt(40,235,'当前状态',14,'secondary');p.txt(40,269,'未开启',18,bold=True)
    p.rect(24,339,342,153,'soft')
    p.txt(40,359,'开启后',16,'onsoft',True)
    p.txt(40,398,'30分钟后自动关闭，重启也会关闭。',14,'onsoft',maxw=310)
    p.txt(40,429,'不会自动上传，也不会记录输入内容。',14,'onsoft',maxw=310)
    p.txt(40,460,'记录量会增加，仍受保存上限限制。',14,'onsoft',maxw=310)
    p.txt(24,526,'建议的排查步骤',16,bold=True)
    for y,s in [(569,'1. 开启详细诊断'),(609,'2. 返回训练，重新操作一次'),(649,'3. 回到这里，导出诊断包')]:p.txt(24,y,s,16,maxw=342)
    p.footer('开启30分钟','只在排查问题时使用。')

def partial(p):
    p.header('导出诊断包')
    p.rect(24,133,342,126,'warnbg')
    p.txt(40,153,'已保存，部分信息不可用',22,'warning',True,maxw=310)
    p.txt(40,197,'已导出可读取的日志。',14,'warning')
    p.txt(40,226,'部分历史日志损坏，未包含在文件中。',14,'warning',maxw=310)
    p.rect(24,285,342,176)
    p.txt(40,305,'已保存的文件',14,'secondary')
    p.txt(40,340,'SetTrace-diagnostics-',16,bold=True)
    p.txt(40,369,'20261023-153000-CD34.zip',16,bold=True,maxw=310)
    p.txt(40,417,'Download · 980 KiB',14,'secondary')
    p.txt(24,496,'缺失范围已在包内说明。',16)
    p.txt(24,536,'你仍可分享现有文件，帮助分析问题。',14,'secondary',maxw=342)
    p.txt(24,576,'若需要更完整的线索，可重新复现问题',14,'secondary',maxw=342)
    p.txt(24,603,'后再导出。',14,'secondary')
    p.footer('完成','已导出的文件由你自行保管。')

def startup(p):
    p.txt(24,61,'SetTrace',24,bold=True)
    p.rect(24,150,56,56,'dangerbg',28)
    p.line([(52,165),(52,183)],'danger',3);p.rect(50,188,4,4,'danger',2)
    p.txt(24,238,'暂时无法打开本机数据',24,bold=True,maxw=342)
    p.txt(24,288,'读取训练数据时发生问题。',16)
    p.txt(24,321,'可以先重试，或导出已有诊断信息。',16,maxw=342)
    p.rect(24,381,342,117,'surface')
    p.txt(40,401,'帮助排查',16,bold=True)
    p.txt(40,438,'已有日志可帮助分析本次启动问题。',14,'secondary',maxw=310)
    p.txt(40,466,'实际数据状态尚未核实。',14,'secondary')
    p.button(603,'导出已有诊断信息','outline')
    p.footer('重试打开','请勿清除应用数据，以免丢失本机记录。')

def main():
    out=[]
    c=board('从最新设置进入，继续原有导出流程','01 / 修订设置入口 · 诊断主页与导出说明保持原设计')
    for x,code,title,fn,note in [
        (40,'L00','设置 · 滚动到数据',settings,('按最新截图保留数据与关于卡片样式。','完整外观、语言与提醒设置另见长图。')),
        (485,'L01','诊断与日志',home,('优先展示保存范围与容量，底部固定导出。','详细诊断与清理为次要操作。')),
        (930,'L02','导出前说明',preview,('范围、位置、包含内容与隐私一次说清。','点击保存后才执行真实文件操作。'))]:
        caption(c,x,code,title,note);fn(Phone(c,x))
    c.save('01-main-flow');out+=c.overflows
    c=board('过程可理解，结果可核实','02 / 导出处理、保存结果与深色对照')
    for x,code,title,fn,dark,note in [
        (40,'L03','正在导出',progress,False,('按真实阶段展示，不使用虚假百分比。','处理期间训练继续，取消后清理半成品。')),
        (485,'L04','文件保存成功',success,False,('完整显示真实文件名、位置及文件大小。','下载文件由用户保管，不自动发送。')),
        (930,'L01','深色主题',home,True,('使用现有深色语义色，布局与浅色一致。','四种主题色可沿现有配色体系映射。'))]:
        caption(c,x,code,title,note);fn(Phone(c,x,dark=dark))
    c.save('02-export-and-dark');out+=c.overflows
    c=board('需要排查时深入，出现故障时仍有出口','03 / 按需记录、部分导出与启动故障')
    for x,code,title,fn,note in [
        (40,'L05','临时详细诊断',detail,('独立说明页，开启前清楚交代期限与用途。','开启后显示结束时刻和“立即关闭”。')),
        (485,'L06','部分信息不可用',partial,('黄色说明诊断信息有缺失，文件已保存。','不与“保存失败”混为一种状态。')),
        (930,'L07','启动失败的诊断入口',startup,('不依赖训练数据库，仍可导出已有信息。','不猜测数据是否完好，不引导清除数据。'))]:
        caption(c,x,code,title,note);fn(Phone(c,x))
    c.save('03-support-states');out+=c.overflows
    def luminance(color):
        rgb=[int(color[i:i+2],16)/255 for i in (1,3,5)]
        linear=[v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4 for v in rgb]
        return sum(v*w for v,w in zip(linear,[0.2126,0.7152,0.0722]))
    contrasts=[]
    for name,tokens in [('light',LIGHT),('dark',DARK)]:
        for fg,bg in [('text','bg'),('text','surface'),('secondary','bg'),('secondary','surface'),('on','accent'),('onsoft','soft'),('warning','warnbg'),('danger','bg')]:
            values=sorted([luminance(tokens[fg]),luminance(tokens[bg])])
            ratio=(values[1]+0.05)/(values[0]+0.05)
            contrasts.append(dict(theme=name,pair=f'{fg}/{bg}',ratio=round(ratio,2),passes_normal_text=ratio>=4.5))
    report={'text_width_overflows':out,'render_scale':SCALE,'text_color_contrasts':contrasts,'scope':'Static design sketches only; no runtime, interaction or accessibility test claims.'}
    (ROOT/'sketch-checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'boards':3,'screens':9,'text_width_overflows':out,'text_color_pairs_checked':len(contrasts),'contrast_failures':[c for c in contrasts if not c['passes_normal_text']]},ensure_ascii=False))

if __name__=='__main__':main()
