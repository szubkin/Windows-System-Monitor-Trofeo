Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if (!('TrofeoUi.DarkTheme' -as [type])) {
Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;
namespace TrofeoUi {
public class DarkMenuRenderer : ToolStripRenderer {
    static readonly Color Background=Color.FromArgb(43,43,43), Hover=Color.FromArgb(65,65,65);
    protected override void OnRenderToolStripBackground(ToolStripRenderEventArgs e){e.Graphics.Clear(Background);}
    protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e){using(var p=new Pen(Color.FromArgb(83,83,83)))e.Graphics.DrawRectangle(p,0,0,e.ToolStrip.Width-1,e.ToolStrip.Height-1);}
    protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e){using(var b=new SolidBrush(e.Item.Selected && e.Item.Enabled ? Hover:Background))e.Graphics.FillRectangle(b,new Rectangle(Point.Empty,e.Item.Size));}
    protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e){e.TextColor=e.Item.Enabled?Color.FromArgb(240,240,240):Color.FromArgb(155,155,155);base.OnRenderItemText(e);}
    protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e){using(var p=new Pen(Color.FromArgb(76,76,76)))e.Graphics.DrawLine(p,12,e.Item.Height/2,e.Item.Width-12,e.Item.Height/2);}
    protected override void OnRenderItemCheck(ToolStripItemImageRenderEventArgs e){using(var p=new Pen(Color.FromArgb(240,240,240),2)){int x=e.ImageRectangle.X+2,y=e.ImageRectangle.Y+4;e.Graphics.DrawLines(p,new[]{new Point(x,y+4),new Point(x+4,y+8),new Point(x+11,y)});}}
}
public class DarkTabs : TabControl {
    public DarkTabs(){SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer,true);}
    protected override void OnPaint(PaintEventArgs e){
        e.Graphics.Clear(Color.FromArgb(32,32,32));
        for(int i=0;i<TabCount;i++){
            Rectangle r=GetTabRect(i);
            using(var b=new SolidBrush(i==SelectedIndex?Color.FromArgb(48,48,48):Color.FromArgb(32,32,32)))e.Graphics.FillRectangle(b,r);
            TextRenderer.DrawText(e.Graphics,TabPages[i].Text,Font,r,Color.FromArgb(235,235,235),TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
            if(i==SelectedIndex)using(var p=new Pen(Color.FromArgb(68,226,198),2))e.Graphics.DrawLine(p,r.Left,r.Bottom-2,r.Right,r.Bottom-2);
        }
    }
}
public static class DarkTheme {
    [DllImport("dwmapi.dll")]static extern int DwmSetWindowAttribute(IntPtr hwnd,int attr,ref int value,int size);
    static readonly Color Back=Color.FromArgb(32,32,32), Text=Color.FromArgb(235,235,235), Field=Color.FromArgb(48,48,48);
    public static void Apply(Form form){
        form.BackColor=Back;form.ForeColor=Text;
        form.HandleCreated+=(s,e)=>Title(form);
        if(form.IsHandleCreated)Title(form);
        foreach(Control c in form.Controls)ApplyControl(c);
    }
    static void Title(Form form){try{int on=1;if(DwmSetWindowAttribute(form.Handle,20,ref on,4)!=0)DwmSetWindowAttribute(form.Handle,19,ref on,4);}catch(DllNotFoundException){}}
    static void ApplyControl(Control c){
        c.ForeColor=Text;c.BackColor=Back;
        var button=c as Button;
        if(button!=null){button.UseVisualStyleBackColor=false;button.FlatStyle=FlatStyle.Flat;button.BackColor=Field;button.FlatAppearance.BorderColor=Color.FromArgb(100,100,100);button.FlatAppearance.MouseOverBackColor=Color.FromArgb(65,65,65);button.FlatAppearance.MouseDownBackColor=Color.FromArgb(80,80,80);}
        var tabs=c as TabControl;
        if(tabs!=null){
            tabs.DrawMode=TabDrawMode.OwnerDrawFixed;tabs.SizeMode=TabSizeMode.Fixed;tabs.ItemSize=new Size(120,30);
            tabs.DrawItem+=(s,e)=>{
                using(var b=new SolidBrush(e.Index==tabs.SelectedIndex?Field:Back))e.Graphics.FillRectangle(b,e.Bounds);
                TextRenderer.DrawText(e.Graphics,tabs.TabPages[e.Index].Text,tabs.Font,e.Bounds,Text,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
            };
        }
        var box=c as CheckBox;if(box!=null){box.FlatStyle=FlatStyle.Flat;}
        var number=c as NumericUpDown;
        if(number!=null){number.BackColor=Field;number.ForeColor=Text;number.BorderStyle=BorderStyle.FixedSingle;}
        var combo=c as ComboBox;
        if(combo!=null){
            combo.BackColor=Field;combo.ForeColor=Text;combo.FlatStyle=FlatStyle.Flat;combo.DrawMode=DrawMode.OwnerDrawFixed;
            combo.DrawItem+=(s,e)=>{
                using(var b=new SolidBrush((e.State&DrawItemState.Selected)!=0?Color.FromArgb(65,65,65):Field))e.Graphics.FillRectangle(b,e.Bounds);
                if(e.Index>=0)TextRenderer.DrawText(e.Graphics,combo.GetItemText(combo.Items[e.Index]),e.Font,new Rectangle(e.Bounds.X+4,e.Bounds.Y,e.Bounds.Width-6,e.Bounds.Height),Text,TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);
                if((e.State&DrawItemState.Focus)!=0)e.DrawFocusRectangle();
            };
        }
        foreach(Control child in c.Controls)ApplyControl(child);
    }
    public static void Menu(ContextMenuStrip menu){
        menu.Renderer=new DarkMenuRenderer();menu.BackColor=Color.FromArgb(43,43,43);menu.ForeColor=Text;
        menu.Font=new Font("Segoe UI",9);menu.ShowImageMargin=false;menu.ShowCheckMargin=true;
        menu.Padding=new Padding(1,5,1,5);
        menu.ItemAdded+=(s,e)=>{e.Item.Padding=new Padding(3,4,12,4);};
    }
}
}
"@
}
