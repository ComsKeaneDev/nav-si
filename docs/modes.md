# Modes

[Daniel Kish notes](https://docs.google.com/document/d/1O83ITPj0pLMTkchY-Xl827iza-orG9UEh4Dl\_EaVSHM/edit?usp=sharing) (restricted access)

## Multiclass detection & spatial awareness/visual question-answering (current)

- Use cases:
    - Trying to figure out which suitcase is user's at the airport conveyor belt (use object detection extension with color information, then use text detection to read the luggage tag)

### Additional Calculations
- Color calculations:
    - Matching clothes
    - User given external directions and prompts, “I’m looking for a white building with a blue door,” “direct me to the red luggage”
    - \[Currently color calculation but not integrated into searching prompts\]

- Make 3D: add distance/depth calculations (X-Y-Z) or real-world coordinates to all object detection
    - 2d-to-3d: [SCRATCH (Apple)](https://appleinsider.com/articles/25/12/18/apples-ai-ml-research-papers-show-instant-3d-image-conversion-more)

### Extensions

- Object detection:
    - Use cases:
        - Looking for a bench to sit down on while walking in the park
        - Looking for your house keys
    - Add additional custom datasets to create new object detection classes: bins, stairs, lift, etc. & allow for custom detection
        - Empty seat/empty spot at table (person box overlapping with chair box?); bench in park
        - Bus stops, particular bus coming
        - Door (push/pull) - entering & exiting
        - Trash bins, stairs, escalator, lift, toilets, service counter/check-in, etc.
        - Cane
        - Conference:
            - “Where’s the food/what are the food options?”
            - “Where’s the water/coffee?”

- Text detection:
    - Use cases:
        - Reading signs in the subway, looking for a specific pasta brand at the store, etc.
    - Relevant text in the wild - strategically look for & parse relevant text; filter out non-relevant text
        - Ads vs. text, etc.
        - Character recognition - text, numbers \= posts, etc.
    - Use cases:
        - Signs, labels, markup
            - Airport:
                - Looking for check-in counter
                - Departure board: “When does Detroit depart?
                - Airplane: is the seat belt sign on or off?
            - “I’m looking for the bus stop sign”
            - Names of restaurants walking past on street
        - (Touch screen) menus
            - “I’m looking for a menu in a restaurant”
            - Organize menu in terms of categories
            - Vegetarian: looking for all vegetarian dishes
        - Elevator buttons
        - Name tags at conferences

- Uber/car identification:
    - Compile & embed training images to compare cars
    - User can prompt with specific make & model
    - Model can detect & announce make, model, & length (to navigate around) of surrounding cars

- Facial detection/recognition:
    - Could have 10 saved contacts, memorize faces & notify user when that person comes back into frame, etc.
    - Use cases:
        - Running tally of who’s around the user & where
        - Professional setting \- trying to find someone at conference (when they’re not looking for user), etc.
        - Meeting someone at airport/restaurant
        - Differentiating between siblings
    - Statistical classifier that runs on-device that tells user whether a face is their partner or not, etc.
        - “Face detected, should I blur it or is this a new face?”
    - Privacy concerns:
        - Blur out unknown faces so people aren’t scared of being recorded
        - Maybe encrypt personal face information before sharing data up to servers

- Navigation (built on top of detection):
    - Use cases
        - “Direct me to tube entrance”
        - Find bin with object detection & then ask to enter spatial navigation mode that gives commands to lead user there
    - Add haptic feedback/use the beacon method (VoiceVista) to guide user towards a target
    - Tracking/following someone/something:
        - Helps user follow another person/object

- Spatial awareness:
    - Blob tracking: make augmented datasets of classification paths (TV, TV, TV, laptop, TV) to combat mislabeling & then reclassify in real-time (using intuitive physics; blobs don’t change identity)
        - Use example to build its own training dataset in order to boost future performance
    - Route planning/navigation:
        - x-y coordinates of parked cars on streets
        - Tell user that they’re facing gap between two cars or to turn 45 degrees to left, etc.
    - Spatial reasoning & AI model refinement with contextual labels:
        - AI models have poor spatial reasoning (from photo: “is laptop to right or left of coffee mug?”)
        - Refine with Euclidean x-y coordinates (“Here’s a coffee mug and a laptop: the coffee mug’s at position (4, 3), and the laptop’s at (2, 1): is the laptop to the left or right of the coffee mug?”) and a few labeled examples of spatial reasoning questions \= improved performance
        - With on-device detection model that’s sending stream of x-y coordinates, can start to save examples of situations where user behavior indicates spatial reasoning as data; then can do refinement and improvement on model’s spatial reasoning or build really nice benchmark datasets

- AudioTac:
    - Once find bench, take pic to get description, etc.

## Danger detection mode

Detect potential danger in real-time & warn users: upcoming stairs up/down, baby gate, head-height obstacle, flying object with high probability of collision, etc.

- Challenge: highly individualized, personalized, and contextual; one of the hardest statistical challenges
- Not just tackling segmentation of known objects; trying to forecast the future and evaluate potential outcomes  that are different depending on context
    - If there’s a ball moving really fast towards a person’s body:
        - In a baseball stadium at the batter’s home plate \= not a dangerous situation that should be alerted
        - In an airport \= matters and must be alerted
    - Human intent & capability
        - Older user: if misses a 2-inch step, likely to fall and get injured
        - Younger user: might not fall, not as dangerous
    - Could run diagnostics to do some level of visual impairment evaluation in semi-real time?
- Weird quantum-ness of it all, which is statistical analysis as AI does it: run into uncertainty principle

## Reporting mode: navigational issues

Record video evidence for & report navigational issues; capture, distill, report/distribute issues

- Issue: people with disabilities not being able to report issues
    - Evidence: must capture & distill issue into properly-formatted video and then distributed/submitted to people who can appropriately respond
- No good reporting and aggregation platform
    - Federal & state governments have disability reporting websites but forms are buried
    - Boston has 311 for city infrastructure issues & decent 311 reporting app but tricker for disability-related things and no one has anything like it
- Policy-level intervention
    - Data/statistics about group of people in particular circumstances that could be visually or verbally contextualized
    - Data dashboard: 75% of complaints from blind people at this region in city involve inaudible crosswalks
        - Raise as statistical need for policymakers to evaluate cost vs. impact & help make decision of where to invest resources

## Expert/instructor mode: data collection

- Create living ecosystem of community data (annotated audio/video recordings) from instructors (blind navigation experts: Daniel Kish, Juan Ruiz) to use as training data for LLM
    - Get expert blind people in different situations to teach AI what to tell a blind user in that situation; contextual expertise
- Create custom datasets by collecting video & recording notes
    - Really well specified protocols about type of data needed
    - Cache on phone and then upload to servers
    - Contextualizing different scenarios as they train blind people in different contexts
        - In unique situation where instructor wants to explain how to help blind person, what’s useful for them as a blind person, what they would tell blind user to do to orient themselves and solve a problem in that scenario
    - Have them describe where they are so can match visual video stuff to words they’re using and listen to advice they give
        - “I’m standing on a busy street corner in the city. Let’s go through the steps of what to do here: listen for traffic flow, have you tried…”
        - “Listen for the flow of cars to orient yourself along the curb. Then walk along the car, don’t just spin around…”

## Student mode: AI assistance

Ask for specialized/personalized navigational help from AI instructor (trained on expert data collection) to provide real-time intervention in the moment during navigation, etc.

- Unique transfer of knowledge between expert navigators and students, who need advice of expert navigators
    - Video mode for current AI aides: ask it things, will give randomly-generated advice of generic AI (sighted person) rather than blind person that has uniquely useful strategy for other blind users
- For student in particular scenario:
    - (Camera provides information to contextualize the question: otherwise system doesn’t know that user is on street, etc.)
    - “I’m trying to cross the street right now”
        - Activate AI instructor mode → see if LLM has any contextual training from data collection → perform contextual inference
        - Teaches user life skill of what to do at intersection instead of saying “it’s clear to cross”
    - “Hey, I’m overwhelmed”
        - AI can look at expert recording and say, “When this expert echolocator was at a corner, they listened for the flow of traffic. Why don’t you try listening for the flow of traffic?”
- Misc
    - Lots of training: irregular intersections (especially in UK)
        - Description of intersection \- what kind of crossing is this, where to cross/where to, island/roundabout
    - Straight line travel (open courtyard, lobby, carpark, wide intersection)
        - Spatial audio?

## Sonification mode

- Take pixels, quantize image, and sonify pixels/video stream (have algorithms that can do that)
