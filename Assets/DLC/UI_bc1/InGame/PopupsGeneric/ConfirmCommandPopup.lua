-- CONFIRM COMMAND POPUP
-- This popup occurs when an action needs confirmation.
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_CONFIRMCOMMAND] = function(popupInfo)
	local bAlt = popupInfo.Option1
	local action = GameInfoActions[popupInfo.Data1] or {}
	local unit = UI.GetHeadSelectedUnit()
	if unit then
		SetPopupTitle( "[COLOR_UNIT_TEXT]"..unit:GetName():upper() )
		local portraitIndex, portraitAtlas = UI.GetUnitPortraitIcon( unit )
		Controls.Image:SetHide( not IconHookup( portraitIndex, 256, portraitAtlas, Controls.Image ) )
	end
	SetPopupText( Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_ACTION", action.TextKey or "" ) )
	AddButton( Locale.ConvertTextKey("TXT_KEY_POPUP_YES"), function() Game.SelectionListGameNetMessage( GameMessageTypes.GAMEMESSAGE_DO_COMMAND, action.CommandType, action.CommandData, -1, 0, bAlt ) end )
	AddButton( Locale.ConvertTextKey("TXT_KEY_POPUP_NO") )
end

----------------------------------------------------------------
-- Key Down Processing
----------------------------------------------------------------
PopupInputHandlers[ButtonPopupTypes.BUTTONPOPUP_CONFIRMCOMMAND] = function( uiMsg, wParam )--, lParam )
	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
			HideWindow()
			return true
		end
	end
end
