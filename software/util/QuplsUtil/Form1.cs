using System.Text.RegularExpressions;
using System;
using System.Security.Cryptography;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class TabWidthHelper
{
	private const int EM_SETTABSTOPS = 0x00CB;

	[DllImport("User32.dll", CharSet = CharSet.Auto)]
	public static extern IntPtr SendMessage(IntPtr hWnd, int msg, int wParam, int[] lParam);

	public static void SetTabWidth(TextBox textbox, int tabWidth)
	{
		Graphics graphics = textbox.CreateGraphics();
		var characterWidth = (int)graphics.MeasureString("M", textbox.Font).Width;
		SendMessage(textbox.Handle, EM_SETTABSTOPS, 1, new int[] { tabWidth * 4 });
	}
}

namespace QuplsUtil
{
	public partial class Form1 : Form
	{
		int regUSP = 32;
		int regSSP = 33;
		int regHSP = 34;
		int regMSP = 35;

		public Form1()
		{
			InitializeComponent();
			TabWidthHelper.SetTabWidth(textBox1, 2);
		}

		// PUSHA
		private void button1_Click(object sender, EventArgs e)
		{
			string str;
			int rg, adr;
			int size = Int32.Parse(textBox2.Text);

			adr = 0x300;
			str = "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			adr = 0x301;
			str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			str = str + "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			adr = 0x302;
			str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			str = str + "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			adr = 0x303;
			str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			str = str + "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			adr = 0x304;
			str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			str = str + "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			adr = 0x305;
			str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.aRa=9'd" + regUSP.ToString() + "|om;\r\n";
			str = str + "\t\tinstr.aRt=9'd" + regUSP.ToString() + "|om;\r\n";
			str = str + "\t\tinstr.aRb=9'd0;\r\n";
			str = str + "\t\tinstr.aRc=9'd0;\r\n";
			str = str + "\t\tinstr.ins={21'h1FFF00,2'd2,SP,SP,OP_ADDI};\r\n";
			str = str + "\t\tinstr.pred_btst=6'd0;\r\n";
			str = str + "\tend\r\n";
			textBox1.AppendText(str);

			for (rg = 1; rg < 31; rg++)
			{
				adr = rg + 0x305;
				str = "12'h" + adr.ToString("X3");
				str = str + ":\r\n";
				str = str + "\tbegin\r\n";
				adr = 0x305 + rg + 1;
				str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
				str = str + "\t\tinstr.aRa=9'd"+regUSP.ToString()+"|om;\r\n";
				str = str + "\t\tinstr.aRb=9'd0;\r\n";
				str = str + "\t\tinstr.aRc=9'd" + rg.ToString() + ";\r\n";
				adr = rg - 1;
				str = str + "\t\tif (micro_ir["+adr.ToString()+"])\r\n";
				adr = rg * size;
				str = str + "\t\t\tinstr.ins={21'h" + adr.ToString("X5") + ",2'd2,SP,5'd" + rg.ToString();
				if (size==8)
				{
					str = str + ",OP_STO};\r\n";
				}
				else if (size==16)
				{
					str = str + ",OP_STH};\r\n";
				}
				str = str + "\t\telse\r\n";
				str = str + "\t\t\tinstr.ins={33'd0,OP_NOP};\r\n";
				str = str + "\t\tinstr.pred_btst=6'd0;\r\n";
				str = str + "\tend\r\n";
				textBox1.AppendText(str);
			}
			adr = 0x305 + rg;
			str = "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			adr = 0x305 + rg + 1;
			str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={30'd5,3'd0,OP_BSR};\r\n";
			str = str + "\tend\r\n";
			adr = 0x306 + rg;
			str = str + "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			adr = 0x306 + rg + 1;
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			adr = 0x307 + rg;
			str = str + "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			adr = 0x307 + rg + 1;
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			adr = 0x308 + rg;
			str = str + "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			adr = 0x308 + rg + 1;
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			adr = 0x309 + rg;
			str = str + "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			adr = 0x309 + rg + 1;
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			textBox1.AppendText(str);
		}

		// POPA
		private void button2_Click(object sender, EventArgs e)
		{
			string str;
			int rg, rg1, adr;
			int size = Int32.Parse(textBox2.Text);

			for (rg = 1; rg < 31; rg++)
			{
				adr = rg + 0x360 - 1;
				str = "12'h" + adr.ToString("X3");
				str = str + ":\r\n";
				str = str + "\tbegin\r\n";
				adr = 0x360 + rg;
				str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
				str = str + "\t\tinstr.aRa=9'd"+regUSP.ToString()+"|om;\r\n";
				str = str + "\t\tinstr.aRb=9'd0;\r\n";
				str = str + "\t\tinstr.aRc=9'd0;\r\n";
				rg1 = rg - 1;
				str = str + "\t\tif (micro_ir[" + rg1.ToString() + "]) begin\r\n";
				rg1 = rg;
				adr = rg * size;
				str = str + "\t\t\tinstr.aRt=9'd" + rg1.ToString() + ";\r\n";
				str = str + "\t\t\tinstr.ins={21'h" + adr.ToString("X5") + ",2'd2,SP,5'd" + rg1.ToString();
				if (size == 8)
				{
					str = str + ",OP_LDO};\r\n";
				}
				else if (size == 16)
				{
					str = str + ",OP_LDH};\r\n";
				}
				str = str + "\t\tend\r\n";
				str = str + "\t\telse\r\n";
				str = str + "\t\t\tinstr.ins={33'd0,OP_NOP};\r\n";
				str = str + "\t\tinstr.pred_btst=6'd0;\r\n";
				str = str + "\tend\r\n";
				textBox1.AppendText(str);
			}
			adr = rg + 0x360-1;
			str = "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			adr = 0x360 + rg;
			str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.aRa=9'd" + regUSP.ToString() + "|om;\r\n";
			str = str + "\t\tinstr.aRt=9'd" + regUSP.ToString() + "|om;\r\n";
			str = str + "\t\tinstr.aRb=9'd0;\r\n";
			str = str + "\t\tinstr.aRc=9'd0;\r\n";
			str = str + "\t\tinstr.ins={21'h00100,2'd2,SP,SP,OP_ADDI};\r\n";
			str = str + "\t\tinstr.pred_btst=6'd0;\r\n";
			str = str + "\tend\r\n";
			textBox1.AppendText(str);
			adr = 0x360 + rg;
			str = "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={30'd5,3'd0,OP_BSR};\r\n";
			str = str + "\tend\r\n";
			adr = 0x361 + rg;
			str = str + "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			adr = 0x362 + rg;
			str = str + "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			adr = 0x363 + rg;
			str = str + "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			adr = 0x364 + rg;
			str = str + "12'h" + adr.ToString("X3");
			str = str + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			textBox1.AppendText(str);
		}

		// STCTX
		private void button3_Click(object sender, EventArgs e)
		{
			string str;
			int rg, adr;
			int size = Int32.Parse(textBox2.Text);

			for (rg = 0; rg < 32; rg++)
			{
				adr = rg + 0x100;
				str = "12'h" + adr.ToString("X3");
				str = str + ":\r\n";
				str = str + "\tbegin\r\n";
				adr = 0x100 + rg + 1;
				str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
				if (rg == 0)
				{
					str = str + "\t\tinstr.aRa=9'd0;\r\n";
					str = str + "\t\tinstr.aRb=9'd0;\r\n";
					str = str + "\t\tinstr.aRc=9'd0;\r\n";
					str = str + "\t\tinstr.aRt=MC0;\r\n";
					str = str + "\t\tinstr.ins = {3'd0,2'd0,CSR_CTX,5'h00,5'h00,OP_CSR};\r\n";
				}
				else
				{
					str = str + "\t\tinstr.aRa=MC0;\r\n";
					str = str + "\t\tinstr.aRb=9'd0;\r\n";
					str = str + "\t\tinstr.aRc=9'd" + rg.ToString() + ";\r\n";
					str = str + "\t\tinstr.aRt=9'd0;\r\n";
					adr = rg * size;
					str = str + "\t\tinstr.ins={21'h" + adr.ToString("X5") + ",2'd2,5'd0,5'd" + rg.ToString();
					if (size == 8)
					{
						str = str + ",OP_STO};\r\n";
					}
					else if (size == 16)
					{
						str = str + ",OP_STH};\r\n";
					}
				}
				str = str + "\t\tinstr.pred_btst=6'd0;\r\n";
				str = str + "\tend\r\n";
				textBox1.AppendText(str);
			}

		}

		// LDCTX
		private void button4_Click(object sender, EventArgs e)
		{
			string str;
			int rg, adr;
			int size = Int32.Parse(textBox2.Text);

			for (rg = 0; rg < 32; rg++)
			{
				adr = rg + 0x150;
				str = "12'h" + adr.ToString("X3");
				str = str + ":\r\n";
				str = str + "\tbegin\r\n";
				adr = 0x150 + rg + 1;
				str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
				if (rg == 0)
				{
					str = str + "\t\tinstr.aRa=9'd0;\r\n";
					str = str + "\t\tinstr.aRb=9'd0;\r\n";
					str = str + "\t\tinstr.aRc=9'd0;\r\n";
					str = str + "\t\tinstr.aRt=MC0;\r\n";
					str = str + "\t\tinstr.ins = {3'd0,2'd0,CSR_CTX,5'd0,5'd0,OP_CSR};\r\n";
				}
				else
				{
					str = str + "\t\tinstr.aRa=MC0;\r\n";
					str = str + "\t\tinstr.aRb=9'd0;\r\n";
					str = str + "\t\tinstr.aRc=9'd0;\r\n";
					str = str + "\t\tinstr.aRt=9'd" + rg.ToString() + ";\r\n";
					adr = rg * size;
					str = str + "\t\tinstr.ins={21'h" + adr.ToString("X5") + ",2'd2,5'd0,5'd" + rg.ToString();
					if (size == 8)
					{
						str = str + ",OP_LDO};\r\n";
					}
					else if (size == 16)
					{
						str = str + ",OP_LDH};\r\n";
					}
				}
				str = str + "\t\tinstr.pred_btst=6'd0;\r\n";
				str = str + "\tend\r\n";
				textBox1.AppendText(str);
			}


		}

		// ENTER
		private void button5_Click(object sender, EventArgs e)
		{
			string str;
			int rg, adr=4, adr2, sn;
			int size = Int32.Parse(textBox2.Text);

			adr2 = adr + 1;
			str = "";
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h" + adr2.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={21'h1FFFE0,2'd2,SP,SP,OP_ADDI};\r\n";
			str = str + "\t\tcase(om)\r\n";
			str = str + "\t\t2'd0: begin instr.aRa=9'd" + regUSP.ToString() + "; instr.aRt=9'd" + regUSP.ToString() + "; end\r\n";
			str = str + "\t\t2'd1: begin instr.aRa=9'd" + regSSP.ToString() + "; instr.aRt=9'd" + regSSP.ToString() + "; end\r\n";
			str = str + "\t\t2'd2: begin instr.aRa=9'd" + regHSP.ToString() + "; instr.aRt=9'd" + regHSP.ToString() + "; end\r\n";
			str = str + "\t\t2'd3: begin instr.aRa=9'd" + regMSP.ToString() + "|ipl; instr.aRt=9'd" + regMSP.ToString() + "|ipl; end\r\n";
			str = str + "\t\tendcase\r\n";
			str = str + "\tend\r\n";
			adr++;
			adr2 = adr + 1;
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h" + adr2.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={21'h00000,2'd2,SP,FP,OP_STO};\r\n";
			str = str + "\t\tcase(om)\r\n";
			str = str + "\t\t2'd0: instr.aRa=9'd" + regUSP.ToString() + ";\r\n";
			str = str + "\t\t2'd1: instr.aRa=9'd" + regSSP.ToString() + ";\r\n";
			str = str + "\t\t2'd2: instr.aRa=9'd" + regHSP.ToString() + ";\r\n";
			str = str + "\t\t2'd3: instr.aRa=9'd" + regMSP.ToString() + "|ipl;\r\n";
			str = str + "\t\tendcase\r\n";
			str = str + "\t\tinstr.aRc=FP;\r\n";
			str = str + "\t\tinstr.aRt=9'd0;\r\n";
			str = str + "\tend\r\n";
			adr++;
			adr2 = adr + 1;
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h" + adr2.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={21'h00008,2'd2,SP,LR0,OP_STO};\r\n";
			str = str + "\t\tcase(om)\r\n";
			str = str + "\t\t2'd0: instr.aRa=9'd" + regUSP.ToString() + ";\r\n";
			str = str + "\t\t2'd1: instr.aRa=9'd" + regSSP.ToString() + ";\r\n";
			str = str + "\t\t2'd2: instr.aRa=9'd" + regHSP.ToString() + ";\r\n";
			str = str + "\t\t2'd3: instr.aRa=9'd" + regMSP.ToString() + "|ipl;\r\n";
			str = str + "\t\tendcase\r\n";
			str = str + "\t\tinstr.aRc=LR0;\r\n";
			str = str + "\t\tinstr.aRt=9'd0;\r\n";
			str = str + "\tend\r\n";
			adr++;
			adr2 = adr + 1;
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h" + adr2.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={21'h00010,2'd2,SP,5'd0,OP_STO};\r\n";
			str = str + "\t\tcase(om)\r\n";
			str = str + "\t\t2'd0: instr.aRa=9'd" + regUSP.ToString() + ";\r\n";
			str = str + "\t\t2'd1: instr.aRa=9'd" + regSSP.ToString() + ";\r\n";
			str = str + "\t\t2'd2: instr.aRa=9'd" + regHSP.ToString() + ";\r\n";
			str = str + "\t\t2'd3: instr.aRa=9'd" + regMSP.ToString() + "|ipl;\r\n";
			str = str + "\t\tendcase\r\n";
			str = str + "\t\tinstr.aRc=9'd0;\r\n";
			str = str + "\t\tinstr.aRt=9'd0;\r\n";
			str = str + "\tend\r\n";
			adr++;
			adr2 = adr + 1;
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h" + adr2.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={21'h00018,2'd2,SP,5'd0,OP_STO};\r\n";
			str = str + "\t\tcase(om)\r\n";
			str = str + "\t\t2'd0: instr.aRa=9'd" + regUSP.ToString() + ";\r\n";
			str = str + "\t\t2'd1: instr.aRa=9'd" + regSSP.ToString() + ";\r\n";
			str = str + "\t\t2'd2: instr.aRa=9'd" + regHSP.ToString() + ";\r\n";
			str = str + "\t\t2'd3: instr.aRa=9'd" + regMSP.ToString() + "|ipl;\r\n";
			str = str + "\t\tendcase\r\n";
			str = str + "\t\tinstr.aRc=9'd0;\r\n";
			str = str + "\t\tinstr.aRt=9'd0;\r\n";
			str = str + "\tend\r\n";

			adr++;
			adr2 = adr + 1;
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h" + adr2.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={FN_OR,2'd2,4'd0,5'd0,5'd0,SP,FP,OP_R2};\r\n";
			str = str + "\t\tcase(om)\r\n";
			str = str + "\t\t2'd0: instr.aRa=9'd" + regUSP.ToString() + ";\r\n";
			str = str + "\t\t2'd1: instr.aRa=9'd" + regSSP.ToString() + ";\r\n";
			str = str + "\t\t2'd2: instr.aRa=9'd" + regHSP.ToString() + ";\r\n";
			str = str + "\t\t2'd3: instr.aRa=9'd" + regMSP.ToString() + "|ipl;\r\n";
			str = str + "\t\tendcase\r\n";
			str = str + "\t\tinstr.aRt=FP;\r\n";
			str = str + "\tend\r\n";

			adr++;
			adr2 = adr + 1;
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h" + adr2.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={-{14'd0,micro_ir[11:8],3'd0},2'd2,SP,SP,OP_ADDI};\r\n";
			str = str + "\t\tcase(om)\r\n";
			str = str + "\t\t2'd0: begin instr.aRa=9'd" + regUSP.ToString() + "; instr.aRt=9'd" + regUSP.ToString() + "; end\r\n";
			str = str + "\t\t2'd1: begin instr.aRa=9'd" + regSSP.ToString() + "; instr.aRt=9'd" + regSSP.ToString() + "; end\r\n";
			str = str + "\t\t2'd2: begin instr.aRa=9'd" + regHSP.ToString() + "; instr.aRt=9'd" + regHSP.ToString() + "; end\r\n";
			str = str + "\t\t2'd3: begin instr.aRa=9'd" + regMSP.ToString() + "|ipl; instr.aRt=9'd" + regMSP.ToString() + "|ipl; end\r\n";
			str = str + "\t\tendcase\r\n";
			str = str + "\tend\r\n";

			for (sn = 0; sn < 9; sn++) {
				adr++;
				adr2 = adr + 1;
				str = str + "12'h" + adr.ToString("X3") + ":\r\n";
				str = str + "\tbegin\r\n";
				str = str + "\t\tif (micro_ir[11:8]>4'd" + sn.ToString() + ") begin\r\n";
				str = str + "\t\t\tnext_ip=12'h" + adr2.ToString("X3") + ";\r\n";
				adr2 = sn * size;
				str = str + "\t\t\tinstr.ins={21'h"+adr2.ToString("X5") + ",2'd2,SP,S"+sn.ToString() + "," + (size==8 ? "OP_STO" : "OP_STH") + "};\r\n";
				str = str + "\t\t\tcase(om)\r\n";
				str = str + "\t\t\t2'd0: instr.aRa=9'd" + regUSP.ToString() + ";\r\n";
				str = str + "\t\t\t2'd1: instr.aRa=9'd" + regSSP.ToString() + ";\r\n";
				str = str + "\t\t\t2'd2: instr.aRa=9'd" + regHSP.ToString() + ";\r\n";
				str = str + "\t\t\t2'd3: instr.aRa=9'd" + regMSP.ToString() + "|ipl;\r\n";
				str = str + "\t\t\tendcase\r\n";
				str = str + "\t\t\tinstr.aRc=S" + sn.ToString() + ";\r\n";
				str = str + "\t\t\tinstr.aRt=9'd0;\r\n";
				str = str + "\t\tend\r\n";
				str = str + "\t\telse begin\r\n";
				adr2 = (adr + 10) & 0xffc;
				str = str + "\t\t\tnext_ip=12'h" + adr2.ToString("X3") + ";\r\n";
				str = str + "\t\t\tinstr.ins={33'd0,OP_NOP};\r\n";
				str = str + "\t\tend\r\n";
				str = str + "\tend\r\n";
			}
			adr++;
			adr2 = adr + 1;
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h" + adr2.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={micro_ir[32:12],2'd2,SP,SP,OP_ADDI};\r\n";
			str = str + "\t\tcase(om)\r\n";
			str = str + "\t\t2'd0: begin instr.aRa=9'd" + regUSP.ToString() + "; instr.aRt=9'd" + regUSP.ToString() + "; end\r\n";
			str = str + "\t\t2'd1: begin instr.aRa=9'd" + regSSP.ToString() + "; instr.aRt=9'd" + regSSP.ToString() + "; end\r\n";
			str = str + "\t\t2'd2: begin instr.aRa=9'd" + regHSP.ToString() + "; instr.aRt=9'd" + regHSP.ToString() + "; end\r\n";
			str = str + "\t\t2'd3: begin instr.aRa=9'd" + regMSP.ToString() + "|ipl; instr.aRt=9'd" + regMSP.ToString() + "|ipl; end\r\n";
			str = str + "\t\tendcase\r\n";
			str = str + "\tend\r\n";

			adr++;
			adr2 = adr + 1;
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h" + adr2.ToString("X3") + ";\r\n";
			str = str + "\t\tinstr.ins={16'd0,micro_ir[39:33],2'd2,3'd1,SP,OP_ADDSI};\r\n";
			str = str + "\t\tcase(om)\r\n";
			str = str + "\t\t2'd0: begin instr.aRa=9'd" + regUSP.ToString() + "; instr.aRt=9'd" + regUSP.ToString() + "; end\r\n";
			str = str + "\t\t2'd1: begin instr.aRa=9'd" + regSSP.ToString() + "; instr.aRt=9'd" + regSSP.ToString() + "; end\r\n";
			str = str + "\t\t2'd2: begin instr.aRa=9'd" + regHSP.ToString() + "; instr.aRt=9'd" + regHSP.ToString() + "; end\r\n";
			str = str + "\t\t2'd3: begin instr.aRa=9'd" + regMSP.ToString() + "|ipl; instr.aRt=9'd" + regMSP.ToString() + "|ipl; end\r\n";
			str = str + "\t\tendcase\r\n";
			str = str + "\tend\r\n";

			adr++;
			adr2 = adr + 1;
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";

			adr++;
			adr2 = adr + 1;
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";

			adr++;
			adr2 = adr + 1;
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";

			adr++;
			adr2 = adr + 1;
			str = str + "12'h" + adr.ToString("X3") + ":\r\n";
			str = str + "\tbegin\r\n";
			str = str + "\t\tnext_ip=12'h000;\r\n";
			str = str + "\t\tinstr.ins={33'd0,OP_NOP};\r\n";
			str = str + "\tend\r\n";
			textBox1.AppendText(str);
		}
	}
}
