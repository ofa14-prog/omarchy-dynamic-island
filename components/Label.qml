import QtQuick

Text {
  property bool tabular: false
  property bool strong: false

  renderType: Text.NativeRendering
  textFormat: Text.PlainText
  font.family: Theme.font
  font.pixelSize: 14
  font.weight: strong ? Font.DemiBold : Font.Normal
  font.features: tabular ? { "tnum": 1 } : ({})
  color: Theme.fg
  elide: Text.ElideRight
  verticalAlignment: Text.AlignVCenter
  maximumLineCount: 1
}
