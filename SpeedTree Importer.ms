/*
[INFO]

NAME = SpeedTree Importer
VERSION = 1.0.0
AUTHOR = MastaMan
DEV = SightLine Vision
HELP = 


[1.0.0]

* First release =

[ABOUT]

This script helps import SpeedTree from Unreal Engine.=

[SCRIPT]
*/

fn getScriptInfo s releaseInfo: "" =
(		
	if(releaseInfo != "") do
	(
		r = getINISetting s releaseInfo
		return r
	)
	
	v = getINISetting s "INFO" "VERSION"
	a = getINISetting s "INFO" "AUTHOR"
	n = getINISetting s "INFO" "NAME"
	o = getINISetting s "ABOUT"
	c = getINISetting s "INFO" "DEV"
	h = getINISetting s "INFO" "HELP"
	
	r = for i in (getINISetting s) where i != "ABOUT" and i != "SCRIPT" and i != "COPY" collect i
	
	return #(n, a, v, o, r, c, h)
)

fn parseToLine m = 
(
	if(m.count == 0) do return ""
	
	l = ""				
	for i in m do l += i + "\n"
	return l
)

fn CreateDummy n c =
(
	o = #()
	o = for i in helpers where i.name == n and classOf i == Point collect i
	
	if(o.count == 0) do
	(
		p = Point pos: [0, 0 ,0] box: true cross: false name: n wirecolor: c
		
		h = for i in helpers where classOf i == Point collect i
		
		try(p.pos.x =  h[h.count - 1].pos.x + p.size)catch()
	)
)

fn LinkDummy n z =
(
	o = #()
	o = for i in helpers where i.name == n and classOf i == Point collect i

	if(o.count != 0 and z.count != 0) do		
	(
		for i in z do
		(
			append o[1].children i
			i.wirecolor = o[1].wirecolor
		)
	)
)

fn useSettings k p w =
(	
	d = getFilenamePath  (getThisScriptFilename())
	n = filenameFromPath (getThisScriptFilename())			
	settingsFile = d + @"ini\" + (sysInfo.username) + "_" + n + ".ini"
	szUser = sysInfo.computername
	case w of
	(
		0:
		(
			s = getINISetting settingsFile szUser k
			case p of
			(
				"int": return s as integer
				"float": return s as float
				"bool": if s == "true" then true else false
				default: return s
			)
		)
		default: return setINISetting settingsFile szUser k (p as string)
	)
)

fn isSaved  =
(
	x =(maxFilePath == undefined or maxFilePath.count == 0)
	return not x
)

---------------------------------------------------------------------------------------------------

global iWindowPos = [0.0, 0.0]
global defaultFile = #("", @"c:\temp\trees.ustf")
global engineExt = #(".stf", ".ustf")
global szFile = ""

try(closeRolloutFloater rSpeedTreeImporter)catch()
global rSpeedTreeImporter = newRolloutFloater "SpeedTree Importer" 250 400

rollout rSpeedTreeImport "Trees List"
(	
	group "Engine"
	(
		radiobuttons rdoExportFor  "" labels:#("Neo", "Unreal Engine") align: #left columns: 1 default: 2 enabled: false
	)
	
	group "Custom file"
	(
		edittext edtBrowse "" width:218 height:25 readOnly:true text: "" offset: [-5, 0]
		button btnBrowse "Browse" width:220 height:35	
	)
	
	group "Import Trees"
	(
		spinner spnSize "Box Size:" range:[0.01,99999, (units.decodeValue "100.0cm")] fieldWidth: 70 type: #worldunits align: #left
		label lblStatus "Status: Found 0 trees types!" align: #left
		button btnImportTrees "Import" width:220 height:35	
	)
	
	timer tmrUE_Import "" interval: 10 active: false
	
	fn getStatus =
	(
		treesTypes  = getIniSetting szFile
		
		s = if(treesTypes.count > 1) then "s" else ""
		lblStatus.caption = "Status: Found " + treesTypes.count as string + " tree" + s + " type" + s + "."
	)
	
	fn saveWindowPos =
	(
		useSettings "x"  iWindowPos[1] 1
		useSettings "y"  iWindowPos[2] 1		
	)
	
	on rSpeedTreeImport open do
	(
		x = (useSettings "x" "float" 0) as float
		y = (useSettings "y" "float" 0) as float
	
		try(rSpeedTreeImporter.pos = [x, y]) catch()
		
		i = rdoExportFor.state
		
		szFile = useSettings "FILE" "string" 0
		if(szFile == "" or getFilenameType szFile != engineExt[i]) do szFile = defaultFile[i]
				
		edtBrowse.text = szFile
				
		getStatus()
	)
	
	on rSpeedTreeImport close do
	(
		saveWindowPos()
	)
	
	on rSpeedTreeImport moved p do
	(
		iWindowPos = p
	)
	
	on btnBrowse pressed do
	(
		saveWindowPos()
		
		if(isSaved() == false) do
		(
			q = QueryBox "Warning! Scene not saved!\nSave scene?"
			if(q == true)do max file saveas	
		)
		
		szFile = useSettings "FILE" "string" 0
		
		i = rdoExportFor.state
		if(szFile == "") do szFile = defaultFile[i]
		
		types = "*" + engineExt[i] + "|" + "*" + engineExt[i] 
		szFile = getOpenFileName caption:"Browse"	filename: szFile types: types
		
		if(szFile != undefined and szFile != "") then
		(															
			useSettings "FILE" szFile 1
			edtBrowse.text = szFile						
		)			
	)
	
	fn createTree tree  x y z rotZ scaleZ wireColor=
	(
		s = spnSize.value
		b = Box pos: [x, y, z] width: s height: s length: s  scale: [scaleZ, scaleZ, scaleZ] wirecolor: wireColor name: tree
		
		b.rotation.controller.value = eulerAngles 0 0 rotZ
		
		return b
	)
	
	fn getFloat t = trimLeft(trimRight t) as float
	
	fn UE_ImportTrees =
	(
		treeTypes = getIniSetting szFile
		
		disableSceneRedraw()
		
		for type in treeTypes do
		(
			trees = getIniSetting szFile type
			
			progressStart ("Import " + type + "...")
			escapeEnable
			iCnt = 0
			
			wireColor = random black white
			
			tmpTrees = #()
			
			for tree in trees do
			(
				treeTransform = getIniSetting szFile type tree
				
				data = filterString treeTransform "@"
				trans = filterString data[1] " "
				
				x = getFloat trans[1] 
				y = getFloat trans[2]
				z = getFloat trans[3] 
				
				rotZ = getFloat data[2]
				scaleZ = getFloat data[3]
				
				b = createTree tree  x y z rotZ scaleZ wireColor
				append tmpTrees b
				
				iCnt += 1
				
				progressUpdate (100.0 * iCnt / trees.count)
				if(getProgressCancel() == true)do exit	
			)
			
			progressEnd()
			
			CreateDummy type wireColor
			LinkDummy type tmpTrees
		)
		
		enableSceneRedraw()
		enableSceneRedraw()
		enableSceneRedraw()
		forceCompleteRedraw()
		
			
	)
	
	on tmrUE_Import tick do
	(
		UE_ImportTrees()
		tmrUE_Import.active = false
	)
	
	on btnImportTrees pressed do
	(
		q = queryBox "Do you really want to import trees?" title: "Confirm action"
		if(not q) do return false
		
		if(rdoExportFor.state == 2) do tmrUE_Import.active = true
	)
)

rollout rAbout "About" 
(	
	label lblName "" 
	label lblVer "" 
	
	label lblAuthor "" height: 30
	label lblCopy ""  height: 30
	button btnHelp "Help" enabled: false
	
	fn getHelp run: false =
	(
		s = getThisScriptFilename()
		i = getScriptInfo s
		szHelp = (getFilenamePath s) + i[7]
		if(i[7] != "" and doesFileExist szHelp) do btnHelp.enabled = true
			
		if(run) do ShellLaunch szHelp ""
	)
	
	on btnHelp pressed do getHelp run: true
				
	on rAbout open do
	(		
		i = getScriptInfo (getThisScriptFilename())
			
		lblName.caption = i[1]
		lblAuthor.caption = i[2]
		lblVer.caption = i[3]
		lblCopy.caption = i[6]
		
		getHelp()
	)
)


addRollout rSpeedTreeImport rSpeedTreeImporter rolledUp:false 
addRollout rAbout rSpeedTreeImporter rolledUp:true 