# テスト結果の要約（ゲート: xcodebuild test）

- 判定: **成功**
- 件数: 60 件（成功 60 / 失敗 0 / 再試行で成功した不安定なテスト 0）
- テスト実行の時間: 430 秒（ビルドを含む全体: 443 秒）
- 端末: iPad Pro 11-inch (M5) TEST (26.5)（並列なし）
- xcodebuild の終了コード: 0

## 遅いテスト（上位 10 件）

| 秒 | テスト |
|---|---|
| 95.4 | `CircuitCanvasUITests/testCircuitCataloguePlacementKindsAndTerminals()` |
| 44.9 | `CircuitCanvasUITests/testBlockResizeHandlesSnappingLimitsWiresAndReset()` |
| 37.5 | `CircuitCanvasUITests/testMultiTerminalWiringAdjacentPinsRotationAndMove()` |
| 25.2 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| 21.6 | `CircuitCanvasUITests/testShortHorizontalLineDragsAndCrossings()` |
| 21.3 | `CircuitCanvasUITests/testCircuitRotationControlsPreserveCenterAndWiring()` |
| 16.3 | `CircuitCanvasUITests/testVerticalPowerSegmentDragBranchAndRotation()` |
| 16.3 | `CircuitCanvasUITests/testRequestedRoutesAndSymbolMovementAvoidBodiesAndOverlaps()` |
| 15.5 | `CircuitCanvasUITests/testOperationHintStaysFixedDuringZoomAndPan()` |
| 15.3 | `CircuitCanvasUITests/testStartPinSelectionResetsAndIsReusedWithoutStrayWires()` |

UI テストの所要時間の合計: 404 秒（21 件）。 UI テストは、1 件ごとにアプリを起動し直すため、統合すると起動の回数が減る。

## 全テスト

| 結果 | 秒 | テスト |
|---|---|---|
| Passed | 5.1 | `CircuitCanvasUITests/testBlankCanvasDragCrossingLineRemainsPan()` |
| Passed | 44.9 | `CircuitCanvasUITests/testBlockResizeHandlesSnappingLimitsWiresAndReset()` |
| Passed | 95.4 | `CircuitCanvasUITests/testCircuitCataloguePlacementKindsAndTerminals()` |
| Passed | 21.3 | `CircuitCanvasUITests/testCircuitRotationControlsPreserveCenterAndWiring()` |
| Passed | 25.2 | `CircuitCanvasUITests/testCircuitWiringSelfRejectionMovementAndGroundDeletion()` |
| Passed | 6.8 | `CircuitCanvasUITests/testCloseSymbolsRetainMaximumAvailableLead()` |
| Passed | 9.7 | `CircuitCanvasUITests/testDeletingNoteDoesNotCrash()` |
| Passed | 10.7 | `CircuitCanvasUITests/testDeletingSymbolRemovesNewlyAddedWire()` |
| Passed | 7.5 | `CircuitCanvasUITests/testDraggingOneSideOfAStepStraightensTheWire()` |
| Passed | 6.0 | `CircuitCanvasUITests/testExperimentNoteCanBeDragged()` |
| Passed | 10.8 | `CircuitCanvasUITests/testJunctionsTrackSharedPinsAndSegmentDrags()` |
| Passed | 37.5 | `CircuitCanvasUITests/testMultiTerminalWiringAdjacentPinsRotationAndMove()` |
| Passed | 15.5 | `CircuitCanvasUITests/testOperationHintStaysFixedDuringZoomAndPan()` |
| Passed | 9.6 | `CircuitCanvasUITests/testPinCentersMatchAndWireEndpointsFollowBothDraggedSymbols()` |
| Passed | 16.3 | `CircuitCanvasUITests/testRequestedRoutesAndSymbolMovementAvoidBodiesAndOverlaps()` |
| Passed | 10.4 | `CircuitCanvasUITests/testSegmentDragKeepsEndpointsViewportCountAndManualPosition()` |
| Passed | 4.9 | `CircuitCanvasUITests/testSegmentDragStopsAtBodyBoundary()` |
| Passed | 21.6 | `CircuitCanvasUITests/testShortHorizontalLineDragsAndCrossings()` |
| Passed | 15.3 | `CircuitCanvasUITests/testStartPinSelectionResetsAndIsReusedWithoutStrayWires()` |
| Passed | 16.3 | `CircuitCanvasUITests/testVerticalPowerSegmentDragBranchAndRotation()` |
| Passed | 13.4 | `CircuitCanvasUITests/testWireToolConnectsPinsAndRejectsDuplicatesBothWays()` |
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
| Passed | 0.1 | `WireRoutingTests/initialAndRequestedRoutesAvoidBodiesAndOverlaps()` |
| Passed | 0.0 | `WireRoutingTests/junctionsDeduplicateMultipleBranchesAndExcludePinsAndCrossings()` |
| Passed | 0.0 | `WireRoutingTests/manualRoutesAreReattachedNotReplanned()` |
| Passed | 0.0 | `WireRoutingTests/manualSegmentPositionSurvivesEndpointMovement()` |
| Passed | 0.0 | `WireRoutingTests/overlapIsAllowedOnlyAlongTheTrunkOfASharedPin()` |
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
