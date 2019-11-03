-- CONFIRM CITY TASK POPUP
-- This popup occurs when an action needs confirmation.

PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_CONFIRM_CITY_TASK] = function( popupInfo )
	local cityID	= popupInfo.Data1
	local taskID	= popupInfo.Data2
	SetPopupTitle( UI.GetHeadSelectedCity():GetName():upper() )
	SetPopupText( taskID == TaskTypes.TASK_RAZE and Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_RAZE") or popupInfo.Text or Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE") )
	AddButton( Locale.ConvertTextKey("TXT_KEY_POPUP_YES"), function() Network.SendDoTask( cityID, taskID, -1, -1, false, false, false, false ) end )
	AddButton( Locale.ConvertTextKey("TXT_KEY_POPUP_NO") )
end
