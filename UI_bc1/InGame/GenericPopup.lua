include( "IconSupport.lua" )
-------------------------------------------------
-- Generic Popups
-------------------------------------------------
PopupLayouts = {}
PopupInputHandlers = {}
local mostRecentPopup
local g_isOpen = false
local g_buttons = {}
local g_buttonIdx = 0
------------------------------------------------
-- Misc Utility Methods
------------------------------------------------
-- Shows popup window.
function ShowWindow( popupInfo )
	ResizeWindow()
	UIManager:QueuePopup( ContextPtr, PopupPriority.GenericPopup )
	Events.SerialEventGameMessagePopupShown( popupInfo )
end

-- Hides popup window.
function HideWindow()
    UIManager:DequeuePopup( ContextPtr )
    Events.SerialEventGameMessagePopupProcessed.CallImmediate( mostRecentPopup, 0 )
	mostRecentPopup = nil	
    ClearButtons()
    g_isOpen = false
end

function ResizeWindow()
    Controls.ButtonStack:CalculateSize()
	Controls.ButtonStackFrame:DoAutoSize()
end

-- Sets popup title.
function SetPopupTitle( text )
	Controls.Title:SetText( text )
end

-- Sets popup text.
function SetPopupText( text )
	Controls.PopupText:SetText( text )
end

-- Remove all buttons from popup.
function ClearButtons()
	for _, button in pairs( g_buttons ) do
		button:SetHide( true )
	end
	Controls.Title:SetText()
	Controls.PopupText:SetText()
	Controls.CloseButton:SetHide( true )
	Controls.Image:SetHide( true )
	ResizeWindow()
	g_buttonIdx = 0
end

-- Add a button to popup.
function AddButton( buttonText, buttonClickFunc, strToolTip, bPreventClose )
	g_buttonIdx = g_buttonIdx + 1
	local button = g_buttons[ g_buttonIdx ]
	if button then
		button:SetHide( false )
	else
		button = {}
		ContextPtr:BuildInstanceForControl( "Button", button, Controls.ButtonStack )
		button = button.Button
		g_buttons[ g_buttonIdx ] = button
	end
	button:SetText( buttonText )
	button:SetToolTipString( strToolTip )
	-- By default, button clicks will hide the popup window after executing the click function
	-- This ugly kludge is only used in one case: when viewing a captured city (PuppetCityPopup)
	if not buttonClickFunc then
		button:RegisterCallback( Mouse.eLClick, HideWindow )
	elseif bPreventClose then
		button:RegisterCallback( Mouse.eLClick, buttonClickFunc )
	else
		button:RegisterCallback( Mouse.eLClick, function() buttonClickFunc() return HideWindow() end )
	end
end

-------------------------------------------------
-- On Display
-------------------------------------------------
function OnDisplay( popupInfo )
	if g_isOpen then
		return
	end
	-- Initialize popups
	local initialize = PopupLayouts[ popupInfo.Type ]
	if initialize then
		ClearButtons()
		if initialize( popupInfo ) ~= false then
			ShowWindow( popupInfo )
			mostRecentPopup = popupInfo.Type
			g_isOpen = true
		end
	end
end
Events.SerialEventGameMessagePopup.Add( OnDisplay )

OnCloseButtonClicked = HideWindow

Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnCloseButtonClicked )

-------------------------------------------------
-- Popup Initializers
-------------------------------------------------
local files = include("InGame\\PopupsGeneric\\%w+Popup.lua", true)
table.sort(files)
print( "Loaded Popups\n", table.concat( files, "\n\t" ) )

-------------------------------------------------
-- Keyboard Handler
-------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )

	local specializedInputHandler = PopupInputHandlers[ mostRecentPopup ]
	if specializedInputHandler then
		return specializedInputHandler( uiMsg, wParam, lParam )
	else
		--Eventually trigger the first button once that code is avail
		if uiMsg == KeyEvents.KeyDown and not ContextPtr:IsHidden() then
			return true
		end
	end
end
ContextPtr:SetInputHandler( InputHandler )
