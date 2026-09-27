# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 62 件（成功 62 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 463 秒（ビルドを含む全体: 477 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 101.0 | `CircuitCanvasUITests/testCircuitCataloguePlacementKindsAndTerminals()` |
| 46.6 | `CircuitCanvasUITests/testBlockResizeHandlesSnappingLimitsWiresAndReset()` |
| 39.0 | `CircuitCanvasUITests/testMultiTerminalWiringAdjacentPinsRotationAndMove()` |
| 26.8 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| 22.9 | `CircuitCanvasUITests/testCircuitRotationControlsPreserveCenterAndWiring()` |
| 22.5 | `CircuitCanvasUITests/testShortHorizontalLineDragsAndCrossings()` |
| 17.5 | `CircuitCanvasUITests/testRequestedRoutesAndSymbolMovementAvoidBodiesAndOverlaps()` |
| 16.7 | `CircuitCanvasUITests/testVerticalPowerSegmentDragBranchAndRotation()` |
| 15.9 | `CircuitCanvasUITests/testOperationHintStaysFixedDuringZoomAndPan()` |
| 15.7 | `CircuitCanvasUITests/testStartPinSelectionResetsAndIsReusedWithoutStrayWires()` |

UI テストの所要時間の合計: 425 秒（21 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 7.5 | `CircuitCanvasUITests/testBlankCanvasDragCrossingLineRemainsPan()` |
| Passed | 46.6 | `CircuitCanvasUITests/testBlockResizeHandlesSnappingLimitsWiresAndReset()` |
| Passed | 101.0 | `CircuitCanvasUITests/testCircuitCataloguePlacementKindsAndTerminals()` |
| Passed | 22.9 | `CircuitCanvasUITests/testCircuitRotationControlsPreserveCenterAndWiring()` |
| Passed | 26.8 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| Passed | 7.1 | `CircuitCanvasUITests/testCloseSymbolsRetainMaximumAvailableLead()` |
| Passed | 10.0 | `CircuitCanvasUITests/testDeletingNoteDoesNotCrash()` |
| Passed | 10.8 | `CircuitCanvasUITests/testDeletingSymbolRemovesNewlyAddedWire()` |
| Passed | 7.8 | `CircuitCanvasUITests/testDraggingOneSideOfAStepStraightensTheWire()` |
| Passed | 6.2 | `CircuitCanvasUITests/testExperimentNoteCanBeDragged()` |
| Passed | 11.1 | `CircuitCanvasUITests/testJunctionsTrackSharedPinsAndSegmentDrags()` |
| Passed | 39.0 | `CircuitCanvasUITests/testMultiTerminalWiringAdjacentPinsRotationAndMove()` |
| Passed | 15.9 | `CircuitCanvasUITests/testOperationHintStaysFixedDuringZoomAndPan()` |
| Passed | 10.0 | `CircuitCanvasUITests/testPinCentersMatchAndWireEndpointsFollowBothDraggedSymbols()` |
| Passed | 17.5 | `CircuitCanvasUITests/testRequestedRoutesAndSymbolMovementAvoidBodiesAndOverlaps()` |
| Passed | 10.7 | `CircuitCanvasUITests/testSegmentDragKeepsEndpointsViewportCountAndManualPosition()` |
| Passed | 5.2 | `CircuitCanvasUITests/testSegmentDragStopsAtBodyBoundary()` |
| Passed | 22.5 | `CircuitCanvasUITests/testShortHorizontalLineDragsAndCrossings()` |
| Passed | 15.7 | `CircuitCanvasUITests/testStartPinSelectionResetsAndIsReusedWithoutStrayWires()` |
| Passed | 16.7 | `CircuitCanvasUITests/testVerticalPowerSegmentDragBranchAndRotation()` |
| Passed | 13.7 | `CircuitCanvasUITests/testWireToolConnectsPinsAndRejectsDuplicatesBothWays()` |
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
| Passed | 0.6 | `WireRoutingTests/fuzzedMovesResizesRotationsAndDragsNeverProduceADiagonalWire()` |
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
