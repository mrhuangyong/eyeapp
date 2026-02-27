//
//  MainPanelView.swift
//  eye-app
//
//  Created by Claude on 2026/2/27.
//

import SwiftUI
import Charts
import AVFoundation

/// 主面板视图
struct MainPanelView: View {

    // MARK: - Dependencies

    @ObservedObject private var viewModel: MainPanelViewModel

    // MARK: - Callbacks

    var onShowPreviewWindow: (() -> Void)?

    // MARK: - State

    @State private var selectedTimeRange: TimeRange = .today

    // MARK: - Initialization

    init(viewModel: MainPanelViewModel, onShowPreviewWindow: (() -> Void)? = nil) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.onShowPreviewWindow = onShowPreviewWindow
    }

    // 便利初始化方法（向后兼容）
    init(statsEngine: StatsEngine, alertManager: AlertManager, dataStorage: DataStorage, cameraManager: CameraManager? = nil, config: AppConfig? = nil, onShowPreviewWindow: (() -> Void)? = nil) {
        self._viewModel = ObservedObject(wrappedValue: MainPanelViewModel(
            statsEngine: statsEngine,
            alertManager: alertManager,
            dataStorage: dataStorage,
            cameraManager: cameraManager,
            config: config
        ))
        self.onShowPreviewWindow = onShowPreviewWindow
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // 摄像头预览区域
                    previewSection

                    // 实时统计卡片
                    realtimeStatsSection

                    // 趋势图表
                    trendChartSection

                    // 历史统计
                    historySection
                }
                .padding()
            }

            Divider()

            // 底部控制栏
            footerControls
        }
        .frame(width: 400, height: 550)
        .onAppear {
            viewModel.loadData()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("👁️ EyeApp")
                .font(.headline)

            Spacer()
        }
        .padding()
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📹 摄像头预览")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if viewModel.previewEnabled {
                if let session = viewModel.previewSession, session.isRunning {
                    ZStack(alignment: .bottomTrailing) {
                        CameraPreviewView(
                            session: session,
                            isMirrored: viewModel.previewMirrored
                        )
                        .frame(width: 240, height: 180)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )

                        // 放大按钮
                        Button(action: { onShowPreviewWindow?() }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .padding(6)
                                .background(Color.black.opacity(0.5))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .help("在新窗口中打开")
                    }
                } else {
                    CameraPreviewPlaceholder(message: "摄像头未就绪\n请先开始监测")
                        .frame(width: 240, height: 180)
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Realtime Stats

    private var realtimeStatsSection: some View {
        HStack(spacing: 16) {
            // 当前眨眼频率
            StatCard(
                title: "当前频率",
                value: "\(viewModel.currentBlinkRate)",
                unit: "次/分",
                color: viewModel.fatigueStatus?.color ?? .green
            )

            // 今日总次数
            StatCard(
                title: "今日总眨眼",
                value: "\(viewModel.todayTotalBlinks)",
                unit: "次",
                color: .blue
            )
        }
    }

    // MARK: - Trend Chart

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📊 今日趋势")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if viewModel.trendData.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(viewModel.trendData) { item in
                    BarMark(
                        x: .value("时间", item.minute, unit: .minute),
                        y: .value("眨眼次数", item.blinkCount)
                    )
                    .foregroundStyle((viewModel.fatigueStatus?.color ?? .green).gradient)
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6))
                }
            }
        }
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("暂无数据")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("开始监测后这里将显示眨眼趋势")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📅 历史统计")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 时间范围选择器
            Picker("时间范围", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTimeRange) { _, newRange in
                viewModel.loadHistory(for: newRange)
            }

            Divider()

            // 统计数据
            let stats = viewModel.historyStats

            HStack(spacing: 20) {
                StatRow(label: "平均眨眼频率", value: "\(Int(stats.avgBlinkRate)) 次/分")
                StatRow(label: "疲劳提醒次数", value: "\(stats.fatigueAlerts) 次")
            }

            HStack(spacing: 20) {
                StatRow(label: "累计监测时长", value: stats.formattedDuration)
                StatRow(label: "平均置信度", value: "\(Int(stats.avgConfidence * 100))%")
            }
        }
    }

    // MARK: - Footer

    private var footerControls: some View {
        HStack {
            Spacer()

            Button("清除今日数据") {
                viewModel.clearTodayData()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding()
    }
}

// MARK: - Supporting Views

/// 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

/// 统计行
struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Time Range

enum TimeRange: CaseIterable {
    case today
    case thisWeek
    case thisMonth
    case all

    var title: String {
        switch self {
        case .today: return "今天"
        case .thisWeek: return "本周"
        case .thisMonth: return "本月"
        case .all: return "全部"
        }
    }
}

// MARK: - Preview

#Preview {
    MainPanelView(
        statsEngine: StatsEngine(),
        alertManager: AlertManager(statsEngine: StatsEngine()),
        dataStorage: DataStorage(storageURL: URL(fileURLWithPath: "/tmp"))
    )
}
