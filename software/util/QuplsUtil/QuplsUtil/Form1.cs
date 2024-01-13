using System.Text.RegularExpressions;
using System;

namespace QuplsUtil
{
	public partial class Form1 : Form
	{
		public Form1()
		{
			InitializeComponent();
		}

		private void button1_Click(object sender, EventArgs e)
		{
			string str;
			int rg, adr;

			for (rg = 0; rg < 64; rg++)
			{
				adr = rg + 0x300;
				str = "12'h" + adr.ToString("X3");
				str = str + ":\r\n";
				str = str + "\tbegin\r\n";
				adr = (0x300 + (rg+4)) & 0xffc;
				str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
				str = str + "\t\tif (om==2'd3) begin\r\n";
				str = str + "\t\t\tinstr.aRa=9'd64|ipl;\r\n";
				if (rg==0)
				{
					str = str + "\t\t\tinstr.aRt=9'd64|ipl;\r\n";
				}
				str = str + "\t\tend\r\n";
				str = str + "\t\telse begin\r\n";
				str = str + "\t\t\tinstr.aRa=9'd72|om;\r\n";
				if (rg == 0)
				{
					str = str + "\t\t\tinstr.aRt=9'd72|om;\r\n";
				}
				str = str + "\t\tend\r\n";
				str = str + "\t\tinstr.aRb=9'd0;\r\n";
				str = str + "\t\tinstr.aRc=9'd" + rg.ToString() + ";\r\n";
				if (rg==0)
				{
					str = str + "\t\tinstr.ins={21'h1FFE08,SP,SP,OP_ADDI};\r\n";
				}
				else
				{
					adr = (rg - 1) * 8;
					str = str + "\t\tinstr.ins={21'h" + adr.ToString("X5") + ",SP,6'd" + rg.ToString() + ",OP_STO};\r\n";
				}
				str = str + "\t\tinstr.pred_btst=6'd0;\r\n";
				str = str + "\tend\r\n";
				textBox1.AppendText(str);
			}
		}

		private void button2_Click(object sender, EventArgs e)
		{
			string str;
			int rg, rg1, adr;

			for (rg = 0; rg < 64; rg++)
			{
				adr = rg + 0x360;
				str = "12'h" + adr.ToString("X3");
				str = str + ":\r\n";
				str = str + "\tbegin\r\n";
				adr = (0x360 + (rg + 4)) & 0xffc;
				str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
				str = str + "\t\tif (om==2'd3) begin\r\n";
				str = str + "\t\t\tinstr.aRa=9'd64|ipl;\r\n";
				if (rg == 63)
				{
					str = str + "\t\t\tinstr.aRt=9'd64|ipl;\r\n";
				}
				str = str + "\t\tend\r\n";
				str = str + "\t\telse begin\r\n";
				str = str + "\t\t\tinstr.aRa=9'd72|om;\r\n";
				if (rg == 63)
				{
					str = str + "\t\t\tinstr.aRt=9'd72|om;\r\n";
				}
				str = str + "\t\tend\r\n";
				str = str + "\t\tinstr.aRb=9'd0;\r\n";
				str = str + "\t\tinstr.aRc=9'd0;\r\n";
				if (rg == 63)
				{
					str = str + "\t\tinstr.ins={21'h0001F8,SP,SP,OP_ADDI};\r\n";
				}
				else
				{
					rg1 = rg + 1;
					adr = rg * 8;
					str = str + "\t\tinstr.aRt=9'd" + rg1.ToString() + ";\r\n";
					str = str + "\t\tinstr.ins={21'h" + adr.ToString("X5") + ",SP,6'd" + rg1.ToString() + ",OP_LDO};\r\n";
				}
				str = str + "\t\tinstr.pred_btst=6'd0;\r\n";
				str = str + "\tend\r\n";
				textBox1.AppendText(str);
			}
		}

		private void button3_Click(object sender, EventArgs e)
		{
			string str;
			int rg, adr;

			for (rg = 0; rg < 64; rg++)
			{
				adr = rg + 0x100;
				str = "12'h" + adr.ToString("X3");
				str = str + ":\r\n";
				str = str + "\tbegin\r\n";
				adr = (0x100 + (rg + 4)) & 0xffc;
				str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
				if (rg == 0)
				{
					str = str + "\t\tinstr.aRa=9'd0;\r\n";
					str = str + "\t\tinstr.aRb=9'd0;\r\n";
					str = str + "\t\tinstr.aRc=9'd0;\r\n";
					str = str + "\t\tinstr.aRt=9'd64+MC0;\r\n";
					str = str + "\t\tinstr.ins = {3'd0,2'd0,CSR_CTX,6'h00,MC0,OP_CSR};\r\n";
				}
				else
				{
					str = str + "\t\tinstr.aRa=9'd64+MC0;\r\n";
					str = str + "\t\tinstr.aRb=9'd0;\r\n";
					str = str + "\t\tinstr.aRc=9'd" + rg.ToString() + ";\r\n";
					str = str + "\t\tinstr.aRt=9'd0;\r\n";
					adr = rg * 8;
					str = str + "\t\tinstr.ins={21'h" + adr.ToString("X5") + ",MC0,6'd" + rg.ToString() + ",OP_STO};\r\n";
				}
				str = str + "\t\tinstr.pred_btst=6'd0;\r\n";
				str = str + "\tend\r\n";
				textBox1.AppendText(str);
			}

		}

		private void button4_Click(object sender, EventArgs e)
		{
			string str;
			int rg, adr;

			for (rg = 0; rg < 64; rg++)
			{
				adr = rg + 0x150;
				str = "12'h" + adr.ToString("X3");
				str = str + ":\r\n";
				str = str + "\tbegin\r\n";
				adr = (0x150 + (rg + 4)) & 0xffc;
				str = str + "\t\tnext_ip=12'h" + adr.ToString("X3") + ";\r\n";
				if (rg == 0)
				{
					str = str + "\t\tinstr.aRa=9'd0;\r\n";
					str = str + "\t\tinstr.aRb=9'd0;\r\n";
					str = str + "\t\tinstr.aRc=9'd0;\r\n";
					str = str + "\t\tinstr.aRt=9'd64+MC0;\r\n";
					str = str + "\t\tinstr.ins = {3'd0,2'd0,CSR_CTX,6'h00,MC0,OP_CSR};\r\n";
				}
				else
				{
					str = str + "\t\tinstr.aRa=9'd64+MC0;\r\n";
					str = str + "\t\tinstr.aRb=9'd0;\r\n";
					str = str + "\t\tinstr.aRc=9'd0;\r\n";
					str = str + "\t\tinstr.aRt=9'd" + rg.ToString() + ";\r\n";
					adr = rg * 8;
					str = str + "\t\tinstr.ins={21'h" + adr.ToString("X5") + ",MC0,6'd" + rg.ToString() + ",OP_LDO};\r\n";
				}
				str = str + "\t\tinstr.pred_btst=6'd0;\r\n";
				str = str + "\tend\r\n";
				textBox1.AppendText(str);
			}


		}
	}
}
