import Foundation
import UIKit

enum AITripSummaryPDFRenderer {

    static func makePDF(
        response: AITripSummaryResponse,
        tripName: String,
        destination: String,
        startDate: Date,
        endDate: Date
    ) -> URL? {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "Cashew",
            kCGPDFContextTitle as String: "\(tripName) — Journal",
        ]

        let bounds = CGRect(origin: .zero, size: Layout.pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        let url = outputURL(for: tripName)
        let dateRange = formatDateRange(start: startDate, end: endDate)

        do {
            try renderer.writePDF(to: url) { ctx in
                var pageNumber = 1
                ctx.beginPage()
                let cgContext = ctx.cgContext

                drawHeader(
                    in: cgContext,
                    rect: CGRect(x: 0, y: 0, width: Layout.pageSize.width, height: Layout.headerHeight),
                    tripName: tripName,
                    destination: destination,
                    dateRange: dateRange
                )

                var cursor = CGPoint(x: Layout.margin, y: Layout.headerHeight + Layout.sectionGap)

                drawAllSections(
                    response: response,
                    cursor: &cursor,
                    pageNumber: &pageNumber,
                    ctx: ctx
                )

                drawFooter(in: cgContext, pageNumber: pageNumber)
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Layout

    private enum Layout {
        static let pageSize = CGSize(width: 612, height: 792)
        static let margin: CGFloat = 50
        static let headerHeight: CGFloat = 140
        static let footerReserve: CGFloat = 50
        static let sectionGap: CGFloat = 24
        static let chipBodyGap: CGFloat = 10
        static let bulletIndent: CGFloat = 16

        static var contentWidth: CGFloat { pageSize.width - margin * 2 }
        static var pageBottom: CGFloat { pageSize.height - footerReserve }
        static var subsequentPageTop: CGFloat { 60 }
    }

    private enum Palette {
        static let primary = UIColor(red: 0x36/255.0, green: 0x42/255.0, blue: 0xE9/255.0, alpha: 1)
        static let onSurface = UIColor(red: 0x2C/255.0, green: 0x2F/255.0, blue: 0x30/255.0, alpha: 1)
        static let onSurfaceVariant = UIColor(red: 0.40, green: 0.42, blue: 0.44, alpha: 1)
        static let surface = UIColor(red: 0xF7/255.0, green: 0xF7/255.0, blue: 0xF8/255.0, alpha: 1)
        static let divider = UIColor(white: 0, alpha: 0.08)

        static let gradientStart = UIColor(red: 0x73/255.0, green: 0x35/255.0, blue: 0xCC/255.0, alpha: 1)
        static let gradientEnd = UIColor(red: 0x96/255.0, green: 0x66/255.0, blue: 0xE6/255.0, alpha: 1)
        static let chipFill = UIColor(red: 0x36/255.0, green: 0x42/255.0, blue: 0xE9/255.0, alpha: 0.10)
    }

    private enum Fonts {
        static func rounded(size: CGFloat, weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            if let descriptor = base.fontDescriptor.withDesign(.rounded) {
                return UIFont(descriptor: descriptor, size: size)
            }
            return base
        }

        static let title = rounded(size: 28, weight: .bold)
        static let subtitle = UIFont.systemFont(ofSize: 14, weight: .regular)
        static let sectionTitle = rounded(size: 13, weight: .semibold)
        static let body = UIFont.systemFont(ofSize: 12, weight: .regular)
        static let dayLabel = rounded(size: 10, weight: .semibold)
        static let footer = UIFont.systemFont(ofSize: 9, weight: .regular)
        static let budgetLabel = UIFont.systemFont(ofSize: 12, weight: .regular)
        static let budgetValue = UIFont.systemFont(ofSize: 12, weight: .semibold)
    }

    // MARK: - Header

    private static func drawHeader(in cg: CGContext, rect: CGRect, tripName: String, destination: String, dateRange: String) {
        cg.saveGState()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [Palette.gradientStart.cgColor, Palette.gradientEnd.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
            cg.addRect(rect)
            cg.clip()
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.minX, y: rect.minY),
                end: CGPoint(x: rect.maxX, y: rect.maxY),
                options: []
            )
        } else {
            // Fallback to a flat fill if gradient creation fails (e.g., color-space mismatch).
            cg.setFillColor(Palette.gradientStart.cgColor)
            cg.fill(rect)
        }
        cg.restoreGState()

        let textInsetX = Layout.margin
        let textWidth = rect.width - Layout.margin * 2 - 60

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.title,
            .foregroundColor: UIColor.white,
        ]
        let title = NSAttributedString(string: tripName, attributes: titleAttrs)
        let titleHeight = title.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            context: nil
        ).height
        let titleY = rect.midY - (titleHeight + 10) / 2 - 6
        title.draw(in: CGRect(x: textInsetX, y: titleY, width: textWidth, height: titleHeight))

        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.subtitle,
            .foregroundColor: UIColor.white.withAlphaComponent(0.92),
        ]
        let subtitle = NSAttributedString(
            string: "\(destination)  ·  \(dateRange)",
            attributes: subtitleAttrs
        )
        subtitle.draw(at: CGPoint(x: textInsetX, y: titleY + titleHeight + 6))

        if let icon = UIImage(named: "CashewIcon") {
            let iconSize: CGFloat = 36
            let iconRect = CGRect(
                x: rect.maxX - Layout.margin - iconSize,
                y: rect.midY - iconSize / 2,
                width: iconSize,
                height: iconSize
            )
            let path = UIBezierPath(roundedRect: iconRect, cornerRadius: 8)
            cg.saveGState()
            path.addClip()
            icon.draw(in: iconRect)
            cg.restoreGState()
        }
    }

    // MARK: - Sections

    private static func drawAllSections(
        response: AITripSummaryResponse,
        cursor: inout CGPoint,
        pageNumber: inout Int,
        ctx: UIGraphicsPDFRendererContext
    ) {
        drawSection(
            title: "Overview",
            iconName: "text.quote",
            cursor: &cursor,
            pageNumber: &pageNumber,
            ctx: ctx
        ) { c, _, _ in
            drawParagraph(response.overview, at: &c)
        }

        if !response.highlights.isEmpty {
            drawSection(
                title: "Highlights",
                iconName: "star.fill",
                cursor: &cursor,
                pageNumber: &pageNumber,
                ctx: ctx
            ) { c, _, _ in
                drawBullets(response.highlights, at: &c)
            }
        }

        if !response.dailyRecap.isEmpty {
            drawSection(
                title: "Day by Day",
                iconName: "calendar",
                cursor: &cursor,
                pageNumber: &pageNumber,
                ctx: ctx,
                splittable: true
            ) { c, page, ctx in
                drawDayByDay(response.dailyRecap, cursor: &c, pageNumber: &page, ctx: ctx)
            }
        }

        drawSection(
            title: "Budget",
            iconName: "dollarsign.circle.fill",
            cursor: &cursor,
            pageNumber: &pageNumber,
            ctx: ctx
        ) { c, _, _ in
            drawBudget(response.budgetRecap, at: &c)
        }

        if !response.funFacts.isEmpty {
            drawSection(
                title: "Fun Facts",
                iconName: "lightbulb.fill",
                cursor: &cursor,
                pageNumber: &pageNumber,
                ctx: ctx
            ) { c, _, _ in
                drawBullets(response.funFacts, at: &c)
            }
        }
    }

    /// Draws a chip-titled section. The closure receives the inout cursor and is responsible
    /// for drawing the body and advancing the cursor's y by the height it consumed.
    /// When `splittable` is false, we measure the body first and break to a new page if the
    /// whole block won't fit. Splittable bodies handle their own pagination.
    private static func drawSection(
        title: String,
        iconName: String,
        cursor: inout CGPoint,
        pageNumber: inout Int,
        ctx: UIGraphicsPDFRendererContext,
        splittable: Bool = false,
        body: (inout CGPoint, inout Int, UIGraphicsPDFRendererContext) -> Void
    ) {
        let chipHeight: CGFloat = 22
        if !splittable {
            // Reserve at least chip + chipBodyGap + 1 line of body before page break.
            ensureSpace(for: chipHeight + Layout.chipBodyGap + 40, cursor: &cursor, pageNumber: &pageNumber, ctx: ctx)
        } else {
            ensureSpace(for: chipHeight + Layout.chipBodyGap + 24, cursor: &cursor, pageNumber: &pageNumber, ctx: ctx)
        }

        drawChip(title: title, iconName: iconName, at: CGPoint(x: cursor.x, y: cursor.y))
        cursor.y += chipHeight + Layout.chipBodyGap

        body(&cursor, &pageNumber, ctx)

        cursor.y += Layout.sectionGap
    }

    private static func drawChip(title: String, iconName: String, at origin: CGPoint) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.sectionTitle,
            .foregroundColor: Palette.primary,
        ]
        let titleString = NSAttributedString(string: title, attributes: attrs)
        let titleSize = titleString.size()
        let iconSize: CGFloat = 12
        let innerSpacing: CGFloat = 6
        let horizontalPadding: CGFloat = 10
        let chipWidth = iconSize + innerSpacing + ceil(titleSize.width) + horizontalPadding * 2
        let chipHeight: CGFloat = 22
        let chipRect = CGRect(x: origin.x, y: origin.y, width: chipWidth, height: chipHeight)

        let path = UIBezierPath(roundedRect: chipRect, cornerRadius: chipHeight / 2)
        Palette.chipFill.setFill()
        path.fill()

        let iconConfig = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
        if let icon = UIImage(systemName: iconName, withConfiguration: iconConfig)?.withTintColor(Palette.primary, renderingMode: .alwaysOriginal) {
            let iconRect = CGRect(
                x: chipRect.minX + horizontalPadding,
                y: chipRect.midY - iconSize / 2,
                width: iconSize,
                height: iconSize
            )
            icon.draw(in: iconRect)
        }

        let titleOrigin = CGPoint(
            x: chipRect.minX + horizontalPadding + iconSize + innerSpacing,
            y: chipRect.midY - titleSize.height / 2
        )
        titleString.draw(at: titleOrigin)
    }

    // MARK: - Body drawers

    private static func drawParagraph(_ text: String, at cursor: inout CGPoint) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        let attrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.body,
            .foregroundColor: Palette.onSurface,
            .paragraphStyle: paragraph,
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let height = ceil(attributed.boundingRect(
            with: CGSize(width: Layout.contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            context: nil
        ).height)
        attributed.draw(in: CGRect(x: cursor.x, y: cursor.y, width: Layout.contentWidth, height: height))
        cursor.y += height
    }

    private static func drawBullets(_ items: [String], at cursor: inout CGPoint) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.headIndent = Layout.bulletIndent
        let attrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.body,
            .foregroundColor: Palette.onSurface,
            .paragraphStyle: paragraph,
        ]
        let bulletAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.body,
            .foregroundColor: Palette.primary,
        ]

        for item in items {
            let bullet = NSAttributedString(string: "•", attributes: bulletAttrs)
            bullet.draw(at: CGPoint(x: cursor.x, y: cursor.y))

            let bodyRectWidth = Layout.contentWidth - Layout.bulletIndent
            let attributed = NSAttributedString(string: item, attributes: attrs)
            let height = ceil(attributed.boundingRect(
                with: CGSize(width: bodyRectWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                context: nil
            ).height)
            attributed.draw(in: CGRect(x: cursor.x + Layout.bulletIndent, y: cursor.y, width: bodyRectWidth, height: height))
            cursor.y += height + 4
        }
    }

    private static func drawDayByDay(
        _ recaps: [AIDailyRecap],
        cursor: inout CGPoint,
        pageNumber: inout Int,
        ctx: UIGraphicsPDFRendererContext
    ) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.dayLabel,
            .foregroundColor: Palette.primary,
            .kern: 0.6,
        ]
        let summaryParagraph = NSMutableParagraphStyle()
        summaryParagraph.lineSpacing = 3
        let summaryAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.body,
            .foregroundColor: Palette.onSurface,
            .paragraphStyle: summaryParagraph,
        ]

        for (index, recap) in recaps.enumerated() {
            let label = formatRecapDate(recap.date)
            let labelString = NSAttributedString(string: label.uppercased(), attributes: labelAttrs)
            let labelSize = labelString.size()

            let summaryString = NSAttributedString(string: recap.summary, attributes: summaryAttrs)
            let summaryHeight = ceil(summaryString.boundingRect(
                with: CGSize(width: Layout.contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                context: nil
            ).height)

            let blockHeight = ceil(labelSize.height) + 4 + summaryHeight + (index < recaps.count - 1 ? 14 : 0)
            ensureSpace(for: blockHeight, cursor: &cursor, pageNumber: &pageNumber, ctx: ctx)

            labelString.draw(at: CGPoint(x: cursor.x, y: cursor.y))
            cursor.y += ceil(labelSize.height) + 4

            summaryString.draw(in: CGRect(x: cursor.x, y: cursor.y, width: Layout.contentWidth, height: summaryHeight))
            cursor.y += summaryHeight

            if index < recaps.count - 1 {
                cursor.y += 7
                let dividerRect = CGRect(x: cursor.x, y: cursor.y, width: Layout.contentWidth, height: 0.5)
                Palette.divider.setFill()
                UIRectFill(dividerRect)
                cursor.y += 7
            }
        }
    }

    private static func drawBudget(_ recap: AIBudgetRecap, at cursor: inout CGPoint) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.budgetLabel,
            .foregroundColor: Palette.onSurfaceVariant,
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.budgetValue,
            .foregroundColor: Palette.onSurface,
        ]

        func drawRow(label: String, value: String) {
            let labelString = NSAttributedString(string: label, attributes: labelAttrs)
            labelString.draw(at: CGPoint(x: cursor.x, y: cursor.y))

            let valueString = NSAttributedString(string: value, attributes: valueAttrs)
            let valueWidth = ceil(valueString.size().width)
            valueString.draw(at: CGPoint(x: cursor.x + Layout.contentWidth - valueWidth, y: cursor.y))

            cursor.y += ceil(max(labelString.size().height, valueString.size().height)) + 6
        }

        if let budget = recap.totalBudget {
            drawRow(label: "Budget", value: "\(recap.currency) \(formatAmount(budget))")
        }
        if let spent = recap.totalSpent {
            drawRow(label: "Spent", value: "\(recap.currency) \(formatAmount(spent))")
        }

        if !recap.verdict.isEmpty {
            cursor.y += 4
            let verdictParagraph = NSMutableParagraphStyle()
            verdictParagraph.lineSpacing = 3
            let attrs: [NSAttributedString.Key: Any] = [
                .font: Fonts.body,
                .foregroundColor: Palette.primary,
                .paragraphStyle: verdictParagraph,
            ]
            let verdict = NSAttributedString(string: recap.verdict, attributes: attrs)
            let height = ceil(verdict.boundingRect(
                with: CGSize(width: Layout.contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                context: nil
            ).height)
            verdict.draw(in: CGRect(x: cursor.x, y: cursor.y, width: Layout.contentWidth, height: height))
            cursor.y += height
        }
    }

    // MARK: - Pagination + footer

    private static func ensureSpace(
        for requiredHeight: CGFloat,
        cursor: inout CGPoint,
        pageNumber: inout Int,
        ctx: UIGraphicsPDFRendererContext
    ) {
        if cursor.y + requiredHeight <= Layout.pageBottom { return }
        drawFooter(in: ctx.cgContext, pageNumber: pageNumber)
        ctx.beginPage()
        pageNumber += 1
        cursor = CGPoint(x: Layout.margin, y: Layout.subsequentPageTop)
    }

    private static func drawFooter(in cg: CGContext, pageNumber: Int) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: Fonts.footer,
            .foregroundColor: Palette.onSurfaceVariant,
        ]
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
        let centerText = NSAttributedString(
            string: "Cashew  ·  AI Journal  ·  Generated \(dateString)",
            attributes: attrs
        )
        let centerSize = centerText.size()
        let centerY = Layout.pageSize.height - 30
        centerText.draw(at: CGPoint(
            x: (Layout.pageSize.width - centerSize.width) / 2,
            y: centerY
        ))

        let pageText = NSAttributedString(string: "Page \(pageNumber)", attributes: attrs)
        let pageSize = pageText.size()
        pageText.draw(at: CGPoint(
            x: Layout.pageSize.width - Layout.margin - pageSize.width,
            y: centerY
        ))
    }

    // MARK: - Helpers

    private static func outputURL(for tripName: String) -> URL {
        let invalid = CharacterSet(charactersIn: "/\\:?*\"<>|")
        let safe = tripName
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = (safe.isEmpty ? "Trip" : safe) + "-Journal.pdf"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    private static func formatDateRange(start: Date, end: Date) -> String {
        let label = DateFormatting.shortDayMonth
        return "\(label.string(from: start)) – \(label.string(from: end))"
    }

    private static func formatRecapDate(_ iso: String) -> String {
        if let date = DateFormatting.isoDate.date(from: iso) {
            return DateFormatting.shortDayMonth.string(from: date)
        }
        return iso
    }

    private static func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}
