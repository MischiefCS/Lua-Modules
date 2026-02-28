---
-- @Liquipedia
-- page=Module:ValveOperationalRequirementsTable
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local Arguments = require('Module:Arguments')
local Array = require('Module:Array')
local DateExt = require('Module:Date/Ext')
local Json = require('Module:Json')
local Logic = require('Module:Logic')
local Lua = require('Module:Lua')
local String = require('Module:StringUtils')
local Table = require('Module:Table')
local Variables = require('Module:Variables')

local Widgets = Lua.import('Module:Widget/All')
local WidgetsHtml = Lua.import('Module:Widget/Html/All')
local IconFa = Lua.import('Module:Widget/Image/Icon/Fontawesome')
local Link = Lua.import('Module:Widget/Basic/Link')
local Lpdb = Lua.import('Module:Lpdb')
local Collapsible = Lua.import('Module:Widget/GeneralCollapsible/Default')
local CollapsibleToggle = Lua.import('Module:Widget/GeneralCollapsible/Toggle')

local TableWidgets = Lua.import('Module:Widget/Table2/All')
local Div = WidgetsHtml.Div
local Span = WidgetsHtml.Span
local Abbr = WidgetsHtml.Abbr
local Hr = WidgetsHtml.Hr

-- table2 aliases
local Row = TableWidgets.Row
local Cell = TableWidgets.Cell
local CellHeader = TableWidgets.CellHeader
local Table2 = TableWidgets.Table
local TableBody = TableWidgets.TableBody

local ValveOperationalRequirementsTable = {}

local DEFAULT_VALUE = '&mdash;'
local DITTO_VALUE = '&#12291;'

local VALID_ADDITIONAL_INFO_TYPES = {'announcement', 'amendment'}
local VALVE_GITHUB_URL = 'https://github.com/ValveSoftware/counter-strike'
local VRS_GITHUB_URL_TEMPLATE = '${year}/${filePrefix}_${year}_${month}_${day}.md'
local VRS_GITHUB_URL_BASE = VALVE_GITHUB_URL .. '_regional_standings/tree/main/invitation/'
local TOR_GITHUB_URL = VALVE_GITHUB_URL .. '_rules_and_regs/blob/${commit}/tournament-operation-requirements.md'
local VRS_REGIONS = {
	global = {
		name = 'global',
		displayName = 'Global Standings',
		githubFilePrefix = 'standings_global'
	},
	europe = {
		name = 'europe',
		displayName = 'European Standings',
		githubFilePrefix = 'standings_europe'
	},
	americas = {
		name = 'americas',
		displayName = 'American Standings',
		githubFilePrefix = 'standings_americas'
	},
	asia = {
		name = 'asia',
		displayName = 'Asian Standings',
		githubFilePrefix = 'standings_asia'
	}
}

---@class ValveOperationalRequirementsData
---@field announcement {date: string?, ref: string?}
---@field additionalInfo ValveOperationalRequirementsDataAdditionalInfo[]
---@field inviteDate {date: string?, ref: string?}
---@field vrsData ValveOperationalRequirementsDataVrsData
---@field seedingData ValveOperationalRequirementsDataVrsData
---@field torVersion {commit: string?, link: string?}
---@field exceptions {html: string?, link: string?}
---@field tier string?

---@class ValveOperationalRequirementsDataAdditionalInfo
---@field date string?
---@field ref string?
---@field type 'announcement'|'amendment'

---@class ValveOperationalRequirementsDataVrsData
---@field standings string?
---@field filtering string?
---@field startingRank integer?
---@field date string?
---@field link string?
---@field ref string?

---@param frame Frame
---@return WidgetHtml
function ValveOperationalRequirementsTable.make(frame)
	local args = Arguments.getArgs(frame)
	local data = ValveOperationalRequirementsTable._getData(args)
	local additionalInfoValues = Array.map(data.additionalInfo,
		ValveOperationalRequirementsTable._makeAdditionalInfoDisplay)
	local additionalInfoRefs = Array.map(data.additionalInfo,
		ValveOperationalRequirementsTable._makeAdditionalInfoRef)
	local vrsDisplay = ValveOperationalRequirementsTable._makeVrsDisplay(data.vrsData)
	local explicitSeedingDate = data.vrsData.date ~= data.seedingData.date

	local rows = {
		ValveOperationalRequirementsTable._makeTableRow({
			title = 'Announcement Date',
			contents = data.announcement.date,
			link = data.announcement.ref,
			linkType = 'ref'
		}),
		Row{
			children = {
				CellHeader{children = {'Additional Information'}},
				Cell{children = Logic.emptyOr(Array.interleave(additionalInfoValues, Hr{}), {DEFAULT_VALUE})},
				Cell{children = Array.interleave(additionalInfoRefs, Hr{})},
			}
		},
		ValveOperationalRequirementsTable._makeTableRow({
			title = 'Invite Date',
			contents = data.inviteDate.date and DateExt.toYmdInUtc(data.inviteDate.date) or nil,
			link = data.inviteDate.ref,
			linkType = 'ref'
		}),
		ValveOperationalRequirementsTable._makeTableRow({
			title = 'VRS Region/Filtering',
			contents = vrsDisplay,
			link = data.vrsData.ref,
			linkType = 'ref'
		}),
		ValveOperationalRequirementsTable._makeTableRow({
			title = explicitSeedingDate and 'Invitational VRS' or 'Applicable VRS',
			contents = data.vrsData.date and DateExt.toYmdInUtc(data.vrsData.date) or nil,
			link = data.vrsData.link,
			linkType = 'github'
		}),
		ValveOperationalRequirementsTable._makeTableRow({
			title = WidgetsHtml.Fragment{children = {
				'Applicable ',
				Abbr{children = 'TOR', title = 'Tournament Operating Requirements'}
			}},
			contents = ValveOperationalRequirementsTable._makeTorDisplay(data.torVersion.commit),
			link = data.torVersion.link,
			linkType = 'github'
		}),
		ValveOperationalRequirementsTable._makeTableRow({
			title = 'Exceptions',
			contents = ValveOperationalRequirementsTable._makeExceptionsExpansion(data.exceptions.html),
			link = data.exceptions.link,
			linkType = 'github'
		}),
		Row{
			children = {
				CellHeader{children = {'Tournament Type'}},
				CellHeader{children = {data.tier or 'Unknown'}, attributes = {colspan = 2}}
			}
		}
	}

	if explicitSeedingDate then
		table.insert(rows, 6, ValveOperationalRequirementsTable._makeTableRow({
			title = 'Seeding VRS',
			contents = data.seedingData.date and DateExt.toYmdInUtc(data.seedingData.date) or nil,
			link = data.seedingData.link,
			linkType = 'github'
		}))
	end

	ValveOperationalRequirementsTable._storeLpdbData(data)

	return Table2{
		tableClasses = {''},
		children = {TableBody{children = rows}},
	}
end

---@param commit string?
---@return string
function ValveOperationalRequirementsTable._makeTorLink(commit)
	return String.interpolate(TOR_GITHUB_URL, {commit = Logic.emptyOr(commit, 'main')})
end

---@param commit string|'latest'
---@return Widget
function ValveOperationalRequirementsTable._makeTorDisplay(commit)
	if commit == 'latest' then
		return WidgetsHtml.I{children = {'Latest Version'}}
	end
	return WidgetsHtml.Code{children = {commit}}
end

---@param vrsData ValveOperationalRequirementsDataVrsData
---@return Renderable[]?
function ValveOperationalRequirementsTable._makeVrsDisplay(vrsData)
	local vrsRegion = VRS_REGIONS[vrsData.standings] or {}
	if Logic.isEmpty(vrsRegion) then
		return
	end
	local children = {vrsRegion.displayName}
	if Logic.isNotEmpty(vrsData.startingRank) and vrsData.startingRank ~= 1 then
		table.insert(children, ' ')
		table.insert(children, WidgetsHtml.I{children = {'(Starting at #' .. vrsData.startingRank .. ')'}})
	end
	if Logic.isNotEmpty(vrsData.filtering) then
		table.insert(children, WidgetsHtml.Br{})
		table.insert(children, WidgetsHtml.I{children = {'(Filtered: ' .. vrsData.filtering .. ')'}})
	end
	return children
end

---@param filePrefix string
---@param date string?
---@return string
function ValveOperationalRequirementsTable._makeVrsLink(filePrefix, date)
	if Logic.isEmpty(date) then
		return VRS_GITHUB_URL_BASE
	end
	
	local iso = DateExt.toYmdInUtc(date)
	local dateParams = DateExt.parseIsoDate(iso) --[[@as osdateparam]]
	return VRS_GITHUB_URL_BASE .. String.interpolate(VRS_GITHUB_URL_TEMPLATE, {
		filePrefix = filePrefix,
		year = dateParams.year,
		month = string.format("%02d", dateParams.month),
		day = string.format("%02d", dateParams.day)
	})
end

---@param link string?
---@return IconFontawesomeWidget?
function ValveOperationalRequirementsTable._makeGitHubIcon(link)
    if Logic.isEmpty(link) then return nil end
    return Link{
        children = {IconFa{iconName = 'github'}},
        linktype = 'external',
        link = link
    }
end

---@param link string?
---@return IconFontawesomeWidget?
function ValveOperationalRequirementsTable._makeRefIcon(link)
    if Logic.isEmpty(link) then return nil end
    return Link{
        children = {IconFa{iconName = 'external_link'}},
        linktype = 'external',
        link = link
    }
end

---@param rowData {title: string|Widget[], contents: string|Widget[]?, link: string?, linkType: 'ref'|'github'}
---@return Widget
function ValveOperationalRequirementsTable._makeTableRow(rowData)
	local link
	if Logic.isNotEmpty(rowData.contents) then
		if Logic.isNotEmpty(rowData.link) then
			if rowData.linkType == 'github' then
				link = ValveOperationalRequirementsTable._makeGitHubIcon(rowData.link)
			else
				link = ValveOperationalRequirementsTable._makeRefIcon(rowData.link)
			end
		elseif rowData.linkType == 'ref' then
			link = DITTO_VALUE
		end
	end
	return Row{
		children = {
			CellHeader{children = rowData.title},
			Cell{children = rowData.contents or DEFAULT_VALUE},
			Cell{children = link},
		}
	}

end

---@param exceptions string?
---@return Widget?
function ValveOperationalRequirementsTable._makeExceptionsExpansion(exceptions)
	if Logic.nilIfEmpty(exceptions) == nil then
		return nil
	end
	return Collapsible{
		shouldCollapse = true,
		titleWidget = Div{
			css = {display = 'block'},
			children = {
				CollapsibleToggle{},
			}
		},
		children = {Div{children = {exceptions}}}
	}
end

---@param additionalInfoJson string
---@return ValveOperationalRequirementsDataAdditionalInfo[]
function ValveOperationalRequirementsTable._parseAdditionalInfo(additionalInfoJson)
	local parsedInfo = Json.parseStringified(additionalInfoJson)
	if Logic.isEmpty(parsedInfo) then
		return {}
	end
	return Array.map(parsedInfo, function(infoItem)
		assert(Logic.isNotEmpty(infoItem.type), 'additional info type cannot be empty!')
		assert(Logic.isNotEmpty(infoItem.date), 'additional info date cannot be empty!')
		assert(Table.includes(VALID_ADDITIONAL_INFO_TYPES, infoItem.type),
			infoItem.type .. ' is not a valid additional info type!'
		)
		return {
			date = Logic.nilIfEmpty(DateExt.toYmdInUtc(infoItem.date)),
			type = infoItem.type,
			ref = infoItem.ref
		}
	end)
end

---@param additionalInfoItem ValveOperationalRequirementsDataAdditionalInfo
---@return string
function ValveOperationalRequirementsTable._makeAdditionalInfoDisplay(additionalInfoItem)
	if additionalInfoItem.type == 'amendment' then
		return 'Amended on ' .. additionalInfoItem.date
	end
	return 'Announced on ' .. additionalInfoItem.date
end

---@param additionalInfoItem ValveOperationalRequirementsDataAdditionalInfo
---@return string?
function ValveOperationalRequirementsTable._makeAdditionalInfoRef(additionalInfoItem)
	return tostring(ValveOperationalRequirementsTable._makeRefIcon(additionalInfoItem.ref))
end

---@param args table
---@return ValveOperationalRequirementsData
function ValveOperationalRequirementsTable._getData(args)
	local vrsRegionData = VRS_REGIONS[args.vrsRegion] or {}
	local vrsDate = Logic.isNotEmpty(args.vrsDate) and DateExt.readTimestamp(args.vrsDate) or nil
	local seedingDate = Logic.isNotEmpty(args.seedingDate) and DateExt.readTimestamp(args.seedingDate) or vrsDate
	local inviteDate = Logic.isNotEmpty(args.inviteDate) and DateExt.readTimestamp(args.inviteDate) or nil
	return {
		announcement = {
			date = Logic.nilIfEmpty(args.announcement),
			ref = Logic.nilIfEmpty(args.announcementRef)
		},
		additionalInfo = ValveOperationalRequirementsTable._parseAdditionalInfo(args.additionalInfo),
		inviteDate = {
			date = inviteDate,
			ref = Logic.nilIfEmpty(args.inviteDateRef)
		},
		vrsData = {
			standings = vrsRegionData.name,
			filtering = Logic.nilIfEmpty(args.vrsFilter),
			startingRank = tonumber(Logic.emptyOr(args.vrsStartingRank, 1)),
			date = vrsDate,
			link = ValveOperationalRequirementsTable._makeVrsLink(vrsRegionData.githubFilePrefix, vrsDate),
			ref = Logic.nilIfEmpty(args.vrsRef)
		},
		seedingData = {
			standings = VRS_REGIONS.global.name,
			date = seedingDate,
			link = ValveOperationalRequirementsTable._makeVrsLink(VRS_REGIONS.global.githubFilePrefix, seedingDate),
			ref = Logic.nilIfEmpty(args.seedingRef)
		},
		torVersion = {
			commit = Logic.emptyOr(args.torVersion, 'latest'),
			link = ValveOperationalRequirementsTable._makeTorLink(args.torVersion)
		},
		exceptions = {
			html = Logic.nilIfEmpty(args.exceptions),
			link = Logic.nilIfEmpty(args.exceptionsLink)
		},
		tier = Logic.emptyOr(args.tier, Variables.varDefault('tournament_publishertier'))
	}
end

---@param data ValveOperationalRequirementsData
function ValveOperationalRequirementsTable._storeLpdbData(data)
	if Logic.readBool(Variables.varDefault('disable_LPDB_storage')) then
		return
	end
	local tournamentParent = Variables.varDefault('tournament_parent')
	local tournamentName = Variables.varDefault('tournament_name')
	if Logic.isEmpty(tournamentParent) then
		local title = mw.title.getCurrentTitle()
		tournamentParent = title.text:gsub(' ', '_')
		tournamentName = title.text
	end
	local dataPoint = Lpdb.DataPoint:new{
		objectname = 'vor_' .. tournamentParent,
		type = 'vor_data',
		name = 'Valve Operational Requirements for ' .. tournamentName,
		information = data.tier,
		date = Variables.varDefault('tournament_enddate'),
		extradata = data
	}
	dataPoint:save()
end

return ValveOperationalRequirementsTable
