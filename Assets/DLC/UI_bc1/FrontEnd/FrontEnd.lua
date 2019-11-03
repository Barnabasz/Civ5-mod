-------------------------------------------------
-- FrontEnd
-------------------------------------------------

function ShowHideHandler( bIsHide, bIsInit )

	-- Check for game invites first.  If we have a game invite, we will have flipped 
	-- the Civ5App::eHasShownLegal and not show the legal/touch screens.
	UI.CheckForCommandLineInvitation()

	if not bIsHide then
		Controls.AtlasLogo:SetTextureAndResize( "CivilzationVAtlas.dds" )
		local a, b = Controls.AtlasLogo:GetSizeVal()
		local x, y = UIManager:GetScreenSizeVal()
		local k = math.max( x/a, y/b )
		Controls.AtlasLogo:Resize( a*k+0.4, b*k+0.4 )
		UIManager:SetUICursor( 0 )
		UIManager:QueuePopup( Controls.MainMenu, PopupPriority.MainMenu )
	else
		Controls.AtlasLogo:UnloadTexture()
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler )