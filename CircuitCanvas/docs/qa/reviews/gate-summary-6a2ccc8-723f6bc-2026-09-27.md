# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 67 件（成功 67 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 487 秒（ビルドを含む全体: 491 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 87.8 | `CircuitCanvasUITests/testCircuitCataloguePlacementKindsAndTerminals()` |
| 44.0 | `CircuitCanvasUITests/testBlockResizeHandlesSnappingLimitsWiresAndReset()` |
| 37.5 | `CircuitCanvasUITests/testMultiTerminalWiringAdjacentPinsRotationAndMove()` |
| 27.1 | `CircuitCanvasUITests/testNoteResizeHandlesSnappingAndMinimumSize()` |
| 25.2 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| 23.1 | `CircuitCanvasUITests/testCircuitRotationControlsPreserveCenterAndWiring()` |
| 21.1 | `CircuitCanvasUITests/testShortHorizontalLineDragsAndCrossings()` |
| 18.3 | `CircuitCanvasUITests/testGenericBlockCanBeRenamedAndGivenAnIconFromTheInspector()` |
| 16.1 | `CircuitCanvasUITests/testRequestedRoutesAndSymbolMovementAvoidBodiesAndOverlaps()` |
| 16.1 | `CircuitCanvasUITests/testVerticalPowerSegmentDragBranchAndRotation()` |

UI テストの所要時間の合計: 459 秒（25 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 4.5 | `CircuitCanvasUITests/testBlankCanvasDragCrossingLineRemainsPan()` |
| Passed | 44.0 | `CircuitCanvasUITests/testBlockResizeHandlesSnappingLimitsWiresAndReset()` |
| Passed | 87.8 | `CircuitCanvasUITests/testCircuitCataloguePlacementKindsAndTerminals()` |
| Passed | 23.1 | `CircuitCanvasUITests/testCircuitRotationControlsPreserveCenterAndWiring()` |
| Passed | 25.2 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| Passed | 6.7 | `CircuitCanvasUITests/testCloseSymbolsRetainMaximumAvailableLead()` |
| Passed | 9.6 | `CircuitCanvasUITests/testDeletingNoteDoesNotCrash()` |
| Passed | 10.4 | `CircuitCanvasUITests/testDeletingSymbolRemovesNewlyAddedWire()` |
| Passed | 7.4 | `CircuitCanvasUITests/testDraggingOneSideOfAStepStraightensTheWire()` |
| Passed | 5.9 | `CircuitCanvasUITests/testExperimentNoteCanBeDragged()` |
| Passed | 18.3 | `CircuitCanvasUITests/testGenericBlockCanBeRenamedAndGivenAnIconFromTheInspector()` |
| Passed | 8.8 | `CircuitCanvasUITests/testInspectorHasNoRotateOrRelateButtons()` |
| Passed | 10.6 | `CircuitCanvasUITests/testJunctionsTrackSharedPinsAndSegmentDrags()` |
| Passed | 37.5 | `CircuitCanvasUITests/testMultiTerminalWiringAdjacentPinsRotationAndMove()` |
| Passed | 11.4 | `CircuitCanvasUITests/testNoteRelateButtonWorksWithoutOpeningTheInspector()` |
| Passed | 27.1 | `CircuitCanvasUITests/testNoteResizeHandlesSnappingAndMinimumSize()` |
| Passed | 15.2 | `CircuitCanvasUITests/testOperationHintStaysFixedDuringZoomAndPan()` |
| Passed | 9.5 | `CircuitCanvasUITests/testPinCentersMatchAndWireEndpointsFollowBothDraggedSymbols()` |
| Passed | 16.1 | `CircuitCanvasUITests/testRequestedRoutesAndSymbolMovementAvoidBodiesAndOverlaps()` |
| Passed | 10.2 | `CircuitCanvasUITests/testSegmentDragKeepsEndpointsViewportCountAndManualPosition()` |
| Passed | 4.8 | `CircuitCanvasUITests/testSegmentDragStopsAtBodyBoundary()` |
| Passed | 21.1 | `CircuitCanvasUITests/testShortHorizontalLineDragsAndCrossings()` |
| Passed | 15.0 | `CircuitCanvasUITests/testStartPinSelectionResetsAndIsReusedWithoutStrayWires()` |
| Passed | 16.1 | `CircuitCanvasUITests/testVerticalPowerSegmentDragBranchAndRotation()` |
| Passed | 13.0 | `CircuitCanvasUITests/testWireToolConnectsPinsAndRejectsDuplicatesBothWays()` |
| Passed | 0.0 | `CircuitSymbolTests/blockPinsUseTheFirstRowSlotAndBodiesFollowTheSize()` |
| Passed | 0.0 | `CircuitSymbolTests/blockSizesSnapToThirtyPointStepsWithinLimits()` |
| Passed | 0.0 | `CircuitSymbolTests/catalogueCategoriesAndVectorGeometry()` |
| Passed | 0.0 | `CircuitSymbolTests/defaultPowerOrientationsAndUprightLetters()` |
| Passed | 0.0 | `CircuitSymbolTests/draggingACornerKeepsTheOppositeCornerFixed()` |
| Passed | 0.0 | `CircuitSymbolTests/externalLeadsAreFifteenPointsExceptNarrowPlateSymbols()` |
| Passed | 0.0 | `CircuitSymbolTests/multiTerminalPinLayoutsMatchTheSpecification()` |
| Passed | 0.0 | `CircuitSymbolTests/multiTerminalShapesReachEveryPin()` |
| Passed | 0.0 | `CircuitSymbolTests/pinsBodyAndOutwardDirectionsForEveryKindAndRotation()` |
| Passed | 0.0 | `CircuitSymbolTests/plateSymbolsKeepTheirPlatesClose()` |
| Passed | 0.0 | `CircuitSymbolTests/resizeHandlesAreFingerSizedAndClearOfPinsAtEveryZoom()` |
| Passed | 0.0 | `CircuitSymbolTests/screenConstantGrowsBelowFullZoomAndNeverShrinksAboveIt()` |
| Passed | 0.0 | `CircuitSymbolTests/twoTerminalAndSingleTerminalSymbolsKeepTheirOriginalPinOrder()` |
| Passed | 0.0 | `CircuitSymbolTests/wireEndsFollowTheirOwnPinWhenNewPinsCoincideWithOldOnes()` |
| Passed | 0.0 | `WireRoutingTests/aKeptWireThatNowOverlapsAManualRouteIsPlannedAgain()` |
| Passed | 0.0 | `WireRoutingTests/aStraightenedManualRouteStillFollowsItsMovedEnds()` |
| Passed | 0.0 | `WireRoutingTests/aStraightenedRouteHasNoZeroLengthOrCollinearSegments()` |
| Passed | 0.0 | `WireRoutingTests/aWireThatABodyNowSitsOnIsRoutedAgainAndOthersStay()` |
| Passed | 0.0 | `WireRoutingTests/backgroundHitResolutionRejectsBlankSpaceAndTerminalLeads()` |
| Passed | 0.0 | `WireRoutingTests/closeBodiesUseHalfGapForLeadsAndClearance()` |
| Passed | 0.0 | `WireRoutingTests/crossingTouchUsesPerpendicularMotionForReturnDrag()` |
| Passed | 0.0 | `WireRoutingTests/crossingsExcludeCornersBranchesAndRecomputeAfterMovement()` |
| Passed | 0.0 | `WireRoutingTests/draggingOneSideOfAStepOntoTheOtherMakesOneStraightSegment()` |
| Passed | 0.0 | `WireRoutingTests/firstRoutingPlansEveryWireInOrderAndLaterRoutingKeepsUnrelatedOnes()` |
| Passed | 0.8 | `WireRoutingTests/fuzzedMovesResizesRotationsAndDragsNeverProduceADiagonalWire(seed:)` |
| Passed | 0.1 | `WireRoutingTests/initialAndRequestedRoutesAvoidBodiesAndOverlaps()` |
| Passed | 0.0 | `WireRoutingTests/junctionsDeduplicateMultipleBranchesAndExcludePinsAndCrossings()` |
| Passed | 0.0 | `WireRoutingTests/manualRoutesAreReattachedNotReplanned()` |
| Passed | 0.0 | `WireRoutingTests/manualSegmentPositionSurvivesEndpointMovement()` |
| Passed | 0.0 | `WireRoutingTests/overlapIsAllowedOnlyAlongTheTrunkOfASharedPin()` |
| Passed | 0.0 | `WireRoutingTests/rerouteReplacesAKeptRouteThatIsNotOrthogonal()` |
| Passed | 0.0 | `WireRoutingTests/rotatedPinsRouteOutwardAvoidBodiesAndShareOnlyTerminalTrunks()` |
| Passed | 0.0 | `WireRoutingTests/routesThroughNarrowGapsStayDraggableAndStillAvoidBodies()` |
| Passed | 0.0 | `WireRoutingTests/segmentDragIsPerpendicularAttachedAndCannotTunnelThroughBody()` |
| Passed | 0.0 | `WireRoutingTests/shortHorizontalDragCreatesAndRemovesCrossingOnOtherWire()` |
| Passed | 0.0 | `WireRoutingTests/shortHorizontalTouchChoosesVisibleLineAndMovesOnlyItsY()` |
| Passed | 0.0 | `WireRoutingTests/snapReachesExactlyThirteenPointsAndNoFurther()` |
| Passed | 0.0 | `WireRoutingTests/snappingNeverPullsASegmentThroughABody()` |
| Passed | 0.0 | `WireRoutingTests/tightLayoutsStillDrawAnOrthogonalWire()` |
| Passed | 0.0 | `WireRoutingTests/verticalTerminalManualDragAndReattachment()` |
| Passed | 0.0 | `WireRoutingTests/wireIsStillDrawnWhenNoPlannedRouteExists()` |
| Passed | 0.0 | `WireRoutingTests/wireLeavesTheFirstRowSlotOfATallBlockSideways()` |
