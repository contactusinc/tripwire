$(document).ready(function() {

	loadOverview();
	setInterval(updateSummaries,10000);
	setInterval(resetOverview,10000);
} )

$.ajaxSetup ({
		cache: false
	});

function datatableAjaxRequest(url)
{
  updateSummaries();
    var dTable = $('#datatb').dataTable( {
                "fnRowCallback": fnRowCallback,
                "bProcessing": true,
                "sPaginationType": "full_numbers",
                //"bServerSide": true,
                "sAjaxSource": url,
		"aaSorting": [[ 0, "asc" ]],
                "fnServerData": function( sUrl, aoData, fnCallback ) {
                        $.ajax( {
                                "url": sUrl,
                                "data": aoData,
                                "type": "GET",
                                "crossDomain": true,
                                "dataType": "jsonp",
                                "cache": false,
				"bDestroy":true
                        } ).done( fnCallback);
                }
    } );
  /* Add event listeners to the two range filtering inputs */
    $('#min').keyup( function() { oTable.fnDraw(); } );
    $('#max').keyup( function() { oTable.fnDraw(); } );
}

function loadOverview()
{
  datatableAjaxRequest(["http://",location.host,":4567/getstatusjsonp/"].join(""));
  updateSummaries();
}
function updateSummaries()
{
  var loadUrl = ["http://",location.host,":4567/getsummaryjson/"].join("");

  $.getJSON( loadUrl, function( data ) {
    $.each( data, function( key, val ) {
      $("#summary_"+key).html(val);
    });
  });
}


function callhistory(history_name)
{
  $('#datatb').dataTable().fnDestroy();
  datatableAjaxRequest(["http://",location.host,":4567/gethistoryjsonp/?appname=",history_name].join(""));
}

function resetOverview()
{
  $('#datatb').dataTable().fnDestroy();
  loadOverview();
}

function fnRowCallback( nRow, aData, iDisplayIndex, iDisplayIndexFull ) {
  var buffer = [ "<a href=javascript:callhistory('",aData[0],"')>",aData[0],"</a>"];
  $('td:eq(0)', nRow).html( buffer.join("") );

  // Bold the grade for all 'A' grade browsers
  if ( aData[6] == "R" )
    {
      $(nRow).css('background-color', '#FFDDDD');
    }else if (aData[6] == "Y" )
    {
      $(nRow).css('background-color', '#FFFADB'); // YELLOW
    }else if (aData[6] == "G" )
    {
      $(nRow).css('background-color', '#DDFFDD'); // GREEN
    }else {
      $(nRow).css('background-color', '#DDDDDD'); // GRAY
    }
}
