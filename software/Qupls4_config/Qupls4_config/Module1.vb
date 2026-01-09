Imports System.IO
Imports System.Windows.Forms.Design

Module Module1
	Public cfgFile(2000) As String
	Public nrows As Integer
	Public Sub UpdateFld(fldname As String, val As Integer)
		Dim n As Integer
		Dim st As Integer
		Dim nd As Integer
		Dim str As String
		Dim fnd As Boolean

		fnd = False
		If Not cfgFile Is Nothing Then
			For n = 0 To nrows - 1
				If Not cfgFile(n) Is Nothing Then
					str = cfgFile(n)
					st = str.IndexOf(fldname)
					If (st > 1) Then
						fnd = True
						nd = st + fldname.Length
						str = str.Substring(0, st)
						str &= fldname & val.ToString & ";"
					End If
					cfgFile(n) = str
				End If
			Next
			If Not fnd Then
				ReDim Preserve cfgFile(n + 1)
				cfgFile(n) = fldname & val.ToString & ";"
			End If
		End If
	End Sub

	Public Sub UpdateStrFld(fldname As String, val As String)
		Dim n As Integer
		Dim st As Integer
		Dim nd As Integer
		Dim str As String
		Dim fnd As Boolean

		fnd = False
		If Not cfgFile Is Nothing Then
			For n = 0 To nrows - 1
				If Not cfgFile(n) Is Nothing Then
					str = cfgFile(n)
					st = str.IndexOf(fldname)
					If (st > 1) Then
						fnd = True
						nd = st + fldname.Length
						str = str.Substring(0, st)
						str &= fldname & val & ";"
					End If
					cfgFile(n) = str
				End If
			Next
			If Not fnd Then
				ReDim Preserve cfgFile(n + 1)
				cfgFile(n) = "parameter " & fldname & val & ";"
				nrows = n + 1
			End If
		End If
	End Sub

End Module
