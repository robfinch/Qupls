Imports System.Data.Common

Public Class Form1
	Dim FileIn, FileOut

	Private Sub UpdateFields()
		Dim strB As String
		Dim strW As String
		Dim strT As String
		Dim strO As String
		Dim strH As String
		Dim prob As Int64
		Dim a As Double
		Dim b As Double


		strB = "_"
		strW = "_"
		strT = "_"
		strO = "_"
		strH = "_"

		prob = NumericUpDown24.Value + (NumericUpDown25.Value * 2.55 << 8) + (NumericUpDown26.Value * 2.55 << 16) + (NumericUpDown27.Value * 2.55 << 24) + (CLng(NumericUpDown28.Value * 2.55) << 32) + (CLng(NumericUpDown29.Value * 2.55) << 40) + (CLng(NumericUpDown30.Value * 2.55) << 48) + (CLng(NumericUpDown31.Value * 2.55) << 56)
		If prob = 0 Then
			TextBox3.Text = "64'h000000000f0f0f0f"
			UpdateStrFld("THREAD_PROBABILITY = 64'", "000000000f0f0f0f".PadLeft(16, "0"))
		Else
			TextBox3.Text = "64'h" & prob.ToString("x")
			UpdateStrFld("THREAD_PROBABILITY = 64'", prob.ToString("x").PadLeft(16, "0"))
		End If
		UpdateFld("MWIDTH = ", NumericUpDown5.Value)
		UpdateFld("THREADS = ", NumericUpDown5.Value)
		UpdateFld("PREGS = ", NumericUpDown11.Value)
		UpdateFld("NCHECK = ", NumericUpDown10.Value)
		UpdateFld("XSTREAMS = ", NumericUpDown10.Value)
		UpdateFld("ROB_ENTRIES = ", NumericUpDown6.Value)
		UpdateFld("BRANCH_LEVELS = ", NumericUpDown10.Value)
		UpdateFld("ISTACK_DEPTH = ", NumericUpDown13.Value)
		UpdateFld("SUPPORT_OOOFC = ", IIf(CheckBox12.Checked = True, 1, 0))
		' Dispatch
		UpdateFld("DISPATCH_STRATEGY = ", IIf(RadioButton1.Checked, 0, 1))
		' Issue
		UpdateFld("NRSE_SAU0 = ", NumericUpDown15.Value)
		UpdateFld("NRSE_SAU = ", NumericUpDown16.Value)
		UpdateFld("NRSE_IMUL = ", NumericUpDown17.Value)
		UpdateFld("NRSE_IDIV = ", NumericUpDown18.Value)
		UpdateFld("NRSE_FMA = ", NumericUpDown19.Value)
		UpdateFld("NRSE_FPU = ", NumericUpDown20.Value)
		UpdateFld("NRSE_DFLT = ", NumericUpDown21.Value)
		UpdateFld("NRSE_FCU = ", NumericUpDown22.Value)
		UpdateFld("NRSE_AGEN = ", NumericUpDown23.Value)
		' Memory
		UpdateFld("SUPPORT_STORE_FORWARDING = ", IIf(CheckBox15.Checked = True, 1, 0))
		UpdateFld("NDATA_PORTS = ", NumericUpDown2.Value)
		UpdateFld("LSQ_ENTRIES = ", NumericUpDown7.Value)
		' Decode
		UpdateFld("SUPPORT_FLOAT = ", IIf(CheckBox3.Checked = True, 1, 0))
		UpdateFld("SUPPORT_IMUL = ", IIf(CheckBox28.Checked = True, 1, 0))
		UpdateFld("SUPPORT_IDIV = ", IIf(CheckBox2.Checked = True, 1, 0))
		UpdateFld("SUPPORT_TRIG = ", IIf(CheckBox4.Checked = True, 1, 0))
		UpdateFld("SUPPORT_PRED = ", IIf(CheckBox7.Checked = True, 1, 0))
		UpdateFld("SUPPORT_ATOM = ", IIf(CheckBox8.Checked = True, 1, 0))
		UpdateFld("SUPPORT_CARRY = ", IIf(CheckBox9.Checked = True, 1, 0))
		UpdateFld("SUPPORT_BITFIELD = ", IIf(CheckBox29.Checked = True, 1, 0))
		UpdateFld("SUPPORT_ROTATE = ", IIf(CheckBox30.Checked = True, 1, 0))
		' Debug
		UpdateFld("SERIALIZE = ", IIf(CheckBox1.Checked = True, 1, 0))
		UpdateFld("SUPPORT_NAN_TRACE = ", IIf(CheckBox21.Checked = True, 1, 0))

		If CheckBox16.Checked Then
			strB = "B"
		End If
		If CheckBox17.Checked Then
			strW = "W"
		End If
		If CheckBox18.Checked Then
			strT = "T"
		End If
		If CheckBox19.Checked Then
			strO = "O"
		End If
		If CheckBox20.Checked Then
			strH = "H"
		End If
		UpdateStrFld("SUPPORTED_PRECISIONS = ", Chr(34) & strB & strW & strT & strO & strH & Chr(34))

		a = NumericUpDown11.Value
		b = NumericUpDown9.Value
		TextBox4.Text = a / (b * 40 + IIf(CheckBox23.Checked, 128, 0))
		TextBox4.Refresh()
	End Sub

	Private Sub NumericUpDown5_ValueChanged(sender As Object, e As EventArgs) Handles NumericUpDown5.ValueChanged
		NumericUpDown6.Minimum = 3 * NumericUpDown5.Value
		NumericUpDown6.Increment = NumericUpDown5.Value
		NumericUpDown6.Maximum = (64 / NumericUpDown5.Value) * NumericUpDown5.Value
		If (NumericUpDown6.Value + NumericUpDown5.Value > NumericUpDown6.Maximum) Then
			While (NumericUpDown6.Value Mod NumericUpDown5.Value <> 0)
				NumericUpDown6.Value = NumericUpDown6.Value - 1
			End While
		End If
		While (NumericUpDown6.Value Mod NumericUpDown5.Value <> 0)
			NumericUpDown6.Value = NumericUpDown6.Value + 1
		End While
		NumericUpDown6.Refresh()
	End Sub

	Private Sub NumericUpDown11_ValueChanged(sender As Object, e As EventArgs)
		Dim a As Double
		Dim b As Double

		a = NumericUpDown11.Value
		b = NumericUpDown9.Value
		TextBox1.Text = a / (b * 40 + IIf(CheckBox23.Checked, 128, 0))
		TextBox1.Refresh()
	End Sub

	Private Sub NumericUpDown9_ValueChanged(sender As Object, e As EventArgs) Handles NumericUpDown9.ValueChanged
		Dim a As Double
		Dim b As Double

		a = NumericUpDown11.Value
		b = NumericUpDown9.Value
		TextBox1.Text = a / (b * 40 + IIf(CheckBox23.Checked, 128, 0))
		TextBox1.Refresh()
		Select Case b
			Case 1
				NumericUpDown24.Enabled = True
				NumericUpDown25.Enabled = False
				NumericUpDown26.Enabled = False
				NumericUpDown27.Enabled = False
				NumericUpDown28.Enabled = False
				NumericUpDown29.Enabled = False
				NumericUpDown30.Enabled = False
				NumericUpDown31.Enabled = False
			Case 2
				NumericUpDown24.Enabled = True
				NumericUpDown25.Enabled = True
				NumericUpDown26.Enabled = False
				NumericUpDown27.Enabled = False
				NumericUpDown28.Enabled = False
				NumericUpDown29.Enabled = False
				NumericUpDown30.Enabled = False
				NumericUpDown31.Enabled = False
			Case 3
				NumericUpDown24.Enabled = True
				NumericUpDown25.Enabled = True
				NumericUpDown26.Enabled = True
				NumericUpDown27.Enabled = False
				NumericUpDown28.Enabled = False
				NumericUpDown29.Enabled = False
				NumericUpDown30.Enabled = False
				NumericUpDown31.Enabled = False
			Case 4
				NumericUpDown24.Enabled = True
				NumericUpDown25.Enabled = True
				NumericUpDown26.Enabled = True
				NumericUpDown27.Enabled = True
				NumericUpDown28.Enabled = False
				NumericUpDown29.Enabled = False
				NumericUpDown30.Enabled = False
				NumericUpDown31.Enabled = False
			Case 5
				NumericUpDown24.Enabled = True
				NumericUpDown25.Enabled = True
				NumericUpDown26.Enabled = True
				NumericUpDown27.Enabled = True
				NumericUpDown28.Enabled = True
				NumericUpDown29.Enabled = False
				NumericUpDown30.Enabled = False
				NumericUpDown31.Enabled = False
			Case 6
				NumericUpDown24.Enabled = True
				NumericUpDown25.Enabled = True
				NumericUpDown26.Enabled = True
				NumericUpDown27.Enabled = True
				NumericUpDown28.Enabled = True
				NumericUpDown29.Enabled = True
				NumericUpDown30.Enabled = False
				NumericUpDown31.Enabled = False
			Case 7
				NumericUpDown24.Enabled = True
				NumericUpDown25.Enabled = True
				NumericUpDown26.Enabled = True
				NumericUpDown27.Enabled = True
				NumericUpDown28.Enabled = True
				NumericUpDown29.Enabled = True
				NumericUpDown30.Enabled = True
				NumericUpDown31.Enabled = False
			Case 8
				NumericUpDown24.Enabled = True
				NumericUpDown25.Enabled = True
				NumericUpDown26.Enabled = True
				NumericUpDown27.Enabled = True
				NumericUpDown28.Enabled = True
				NumericUpDown29.Enabled = True
				NumericUpDown30.Enabled = True
				NumericUpDown31.Enabled = True
			Case Else
				NumericUpDown24.Enabled = True
				NumericUpDown25.Enabled = True
				NumericUpDown26.Enabled = False
				NumericUpDown27.Enabled = False
				NumericUpDown28.Enabled = False
				NumericUpDown29.Enabled = False
				NumericUpDown30.Enabled = False
				NumericUpDown31.Enabled = False
		End Select
	End Sub

	Private Sub CheckBox23_CheckedChanged(sender As Object, e As EventArgs)
		Dim a As Double
		Dim b As Double

		a = NumericUpDown11.Value
		b = NumericUpDown9.Value
		TextBox1.Text = a / (b * 40 + IIf(CheckBox23.Checked, 128, 0))
		TextBox1.Refresh()
	End Sub

	Private Sub OpenToolStripMenuItem_Click(sender As Object, e As EventArgs) Handles OpenToolStripMenuItem.Click
		Dim fname As String
		Dim FSO
		Dim n As Integer

		OpenFileDialog1.ShowDialog()
		fname = OpenFileDialog1.FileName
		FSO = CreateObject("Scripting.FileSystemObject")
		nrows = 0
		FileIn = FSO.OpenTextFile(fname, 1) ' 1=for reading
		Do Until FileIn.AtEndOfStream
			cfgFile(nrows) = FileIn.Readline
			nrows += 1
		Loop
		FileIn.close
	End Sub

	Private Sub SaveToolStripMenuItem_Click(sender As Object, e As EventArgs) Handles SaveToolStripMenuItem.Click
		Dim fname As String
		Dim FSO
		Dim n As Integer

		UpdateFields()
		SaveFileDialog1.ShowDialog()
		fname = SaveFileDialog1.FileName
		FSO = CreateObject("Scripting.FileSystemObject")
		FileOut = FSO.OpenTextFile(fname, 2, True) ' 2=for writing
		For n = 0 To nrows - 1
			FileOut.Writeline(cfgFile(n))
		Next
		FileOut.close
	End Sub

	Private Sub Form1_Load(sender As Object, e As EventArgs) Handles MyBase.Load
		Dim n As Integer

		Timer1.Start()
		For n = 0 To 1999
			cfgFile(n) = New String("")
		Next
	End Sub

	Private Sub Label11_Click(sender As Object, e As EventArgs)

	End Sub

	Private Sub NumericUpDown8_ValueChanged(sender As Object, e As EventArgs)
	End Sub

	Private Sub NumericUpDown6_ValueChanged(sender As Object, e As EventArgs) Handles NumericUpDown6.ValueChanged
	End Sub

	Private Sub NumericUpDown10_ValueChanged(sender As Object, e As EventArgs)
	End Sub

	Private Sub CheckBox15_CheckedChanged(sender As Object, e As EventArgs)
	End Sub

	Private Sub CheckBox1_CheckedChanged(sender As Object, e As EventArgs) Handles CheckBox1.CheckedChanged
	End Sub

	Private Sub CheckBox21_CheckedChanged(sender As Object, e As EventArgs) Handles CheckBox21.CheckedChanged
	End Sub

	Private Sub CheckBox2_CheckedChanged(sender As Object, e As EventArgs)
	End Sub

	Private Sub CheckBox4_CheckedChanged(sender As Object, e As EventArgs)
	End Sub

	Private Sub CheckBox3_CheckedChanged(sender As Object, e As EventArgs)
		If CheckBox3.Checked = True Then
			CheckBox4.Enabled = True
			CheckBox5.Enabled = True
		Else
			CheckBox4.Enabled = False
			CheckBox5.Enabled = False
		End If
	End Sub

	Private Sub CheckBox5_CheckedChanged(sender As Object, e As EventArgs)

	End Sub

	Private Sub NumericUpDown2_ValueChanged(sender As Object, e As EventArgs)

	End Sub

	Private Sub NumericUpDown13_ValueChanged(sender As Object, e As EventArgs) Handles NumericUpDown13.ValueChanged

	End Sub

	Private Sub CheckBox7_CheckedChanged(sender As Object, e As EventArgs)

	End Sub

	Private Sub CheckBox8_CheckedChanged(sender As Object, e As EventArgs)

	End Sub

	Private Sub CheckBox9_CheckedChanged(sender As Object, e As EventArgs)

	End Sub

	Private Sub CheckBox6_CheckedChanged(sender As Object, e As EventArgs)

	End Sub

	Private Sub CheckBox12_CheckedChanged(sender As Object, e As EventArgs)

	End Sub

	Private Sub CheckBox16_CheckedChanged(sender As Object, e As EventArgs)

	End Sub

	Private Sub CheckBox17_CheckedChanged(sender As Object, e As EventArgs)

	End Sub

	Private Sub GroupBox3_Enter(sender As Object, e As EventArgs)

	End Sub

	Private Sub NumericUpDown20_ValueChanged(sender As Object, e As EventArgs) Handles NumericUpDown20.ValueChanged

	End Sub

	Private Sub GroupBox5_Enter(sender As Object, e As EventArgs) Handles GroupBox5.Enter

	End Sub

	Private Sub Timer1_Tick(sender As Object, e As EventArgs) Handles Timer1.Tick
		UpdateFields()
	End Sub
End Class
